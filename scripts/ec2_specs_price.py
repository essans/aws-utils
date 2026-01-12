#!/usr/bin/env python3

# High-level overview:
# This script is a wrapper for queryng AWS EC2 CLI for specs and optionally current on-demand pricing.
# Supports callng based on instances by family/pattern and optional vCPU count, then retrieves
# detailed specs including CPU, memory, GPU, storage, and network performance.
# Results are displayed as a DataFrame and can be saved to CSV.
#
# Usage examples:
#   python ec2_specs_price.py --fam t --vcpus 2
#   python ec2_specs_price.py --pattern "g5.*" --price --save g_instances.csv
#
# To do:
#  - a more robust way to pass region configs


import sys
from pathlib import Path
import argparse
import yaml
from typing import Any

import boto3
import pandas as pd

CONFIGS_DIR = Path(__file__).resolve().parents[1] / "configs"
SRC_DIR = Path(__file__).resolve().parents[1] / "src"

sys.path.append(str(SRC_DIR))
sys.path.append(str(CONFIGS_DIR))

import user_configs

from get_prices import ondemand2

with open(CONFIGS_DIR / "regions.yaml", "r") as f:
    REGION_TO_LOCATION = yaml.safe_load(f)


def collect_instance_types(
    pattern: str, 
    vcpus: int, 
    region: str, 
    profile: str
    ) -> list[dict[str, Any]]:

    #Call EC2 DescribeInstanceTypes with filters and return the raw items
    if profile:
        boto3.setup_default_session(profile_name=profile)
    ec2 = boto3.client("ec2", region_name=region)

    filters = [{"Name": "instance-type", "Values": [pattern]}]
    if vcpus is not None:
        filters.append({"Name": "vcpu-info.default-vcpus", "Values": [str(vcpus)]})

    items: list[dict[str, Any]] = []
    next_token: Any = None
    
    while True:
        kwargs = {"Filters": filters}
        if next_token:
            kwargs["NextToken"] = next_token
        resp = ec2.describe_instance_types(**kwargs)
        items.extend(resp.get("InstanceTypes", []))
        next_token = resp.get("NextToken")
        if not next_token:
            break
    return items


def flatten(item: dict[str, Any]) -> dict[str, Any]:
    #Flatten fields to match required columns
    vcpu = item.get("VCpuInfo", {})
    gpuinfo = item.get("GpuInfo")
    ebsinfo = item.get("EbsInfo", {})
    ebsopt = ebsinfo.get("EbsOptimizedInfo") or {}
    netinfo = item.get("NetworkInfo", {})
    meminfo = item.get("MemoryInfo", {})
    inst_storage = item.get("InstanceStorageInfo", {})

    first_gpu = None
    if gpuinfo and gpuinfo.get("Gpus"):
        first_gpu = gpuinfo["Gpus"][0]

    return {
        "Type": item.get("InstanceType"),
        "CurrentGen": item.get("CurrentGeneration"),
        "Arch": ",".join(item.get("ProcessorInfo", {}).get("SupportedArchitectures", [])),
        "CpuCores": vcpu.get("DefaultCores"),
        "CpuThreadsPerCore": vcpu.get("DefaultThreadsPerCore"),
        "VCpu": vcpu.get("DefaultVCpus"),
        "GpuCount": (first_gpu or {}).get("Count"),
        "GpuName": (first_gpu or {}).get("Name"),
        "MemoryMiB": meminfo.get("SizeInMiB"),
        "EbsOnly": ebsinfo.get("EbsOptimizedSupport"),
        "InstanceStorage": inst_storage.get("TotalSizeInGB"),
        "NetPerf": netinfo.get("NetworkPerformance"),
        "EbsBwMbps": ebsopt.get("BaselineBandwidthInMbps"),
        "HasGPU": gpuinfo is not None,
    }



def add_prices_column(df: pd.DataFrame, region: str) -> pd.DataFrame:

    if not region:
        # If region wasn’t specified, use the default session region for EC2 — then map to Pricing location.
        session = boto3.Session()  #was boto3.session.Session()
        region = session.region_name or "us-east-1"

    location = REGION_TO_LOCATION.get(region)
    if not location:
        # Fallback: if we can’t map, just return the df with NaNs
        df["USDPerHour"] = pd.NA
        return df

    pricing = boto3.client("pricing", region_name="us-east-1")

    cache: dict[str, float] = {}
    prices: list[float] = []
    for itype in df["Type"].tolist():
        if itype not in cache:
            price = ondemand2(pricing, itype, location)
            cache[itype] = price if price is not None else float('nan')
        prices.append(cache[itype])

    df["USDPerHr"] = prices

    df.sort_values(by='USDPerHr', ascending=True, inplace=True)
    return df


def main() -> None:
    ap = argparse.ArgumentParser(description="List EC2 instance specs.")
    ap.add_argument("--fam", default="t", help='Instance family/prefix. Pattern is "<fam>*" (default: t).')
    ap.add_argument("--pattern", default=None, help='Override the wildcard pattern (e.g., "g5.*"). If set, --fam is ignored.')
    ap.add_argument("--vcpus", type=int, default=None, help="Optional exact vCPU filter (e.g., 16).")
    ap.add_argument("--region", default=None, help="AWS region (overrides your default/profile).")
    ap.add_argument("--profile", default=None, help="AWS profile name to use.")
    ap.add_argument("--save", default="", help="filename to save CSV in aws/outputs")
    ap.add_argument("--silent", action="store_true", help="Print the DataFrame.")
    ap.add_argument("--price", action="store_true", help="If set, add On-Demand Linux hourly price column.")
    args = ap.parse_args()

    pattern = args.pattern if args.pattern else f"{args.fam}*"
    items = collect_instance_types(pattern=pattern, vcpus=args.vcpus, region=args.region, profile=args.profile)

    rows = [flatten(item) for item in items]
    df = pd.DataFrame(rows).sort_values(["Type"]).reset_index(drop=True)

    if args.price:
        df = add_prices_column(df, args.region)

    if not args.silent:
        with pd.option_context("display.max_rows", 100, "display.max_columns", 80, "display.width", 200):
            print(df.to_string(index=False))

    if args.save:
        save_path = user_configs.OUTPUTS_DIR / (args.save or "default.csv")
        df.to_csv(save_path, index=False)
        print(f"Saved CSV → {save_path}")
        

    #if args.save_parquet:
    #    df.to_parquet(args.save_parquet, index=False)
    #    print(f"Saved Parquet → {args.save_parquet}")


if __name__ == "__main__":
    main()