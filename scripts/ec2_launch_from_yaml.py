#!/usr/bin/env python3


"""
Minimal script to launch an EC2 instance from a YAML spec.
To do: add user-data encoding, key-pair checks.
"""

import sys
import argparse
from pathlib import Path

import boto3
import yaml
import botocore

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.append(str(SRC_DIR))

from aws_logger import aws_log

def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)
    
def extract_instance_name(spec):
    """Return the 'Name' tag value from TagSpecifications for ResourceType=instance."""
    try:
        for ts in spec.get("TagSpecifications", []):
            if ts.get("ResourceType") == "instance":
                for tag in ts.get("Tags", []):
                    if tag.get("Key") == "Name":
                        return tag.get("Value")
        # Fallback: any 'Name' tag anywhere in TagSpecifications
        for ts in spec.get("TagSpecifications", []):
            for tag in ts.get("Tags", []):
                if tag.get("Key") == "Name":
                    return tag.get("Value")
    except Exception:
        pass
    return None

def main():
    ap = argparse.ArgumentParser(description="Launch EC2 instance from YAML (minimal)")
    ap.add_argument("yaml_path", type=Path, help="Path to launch YAML")
    ap.add_argument("--profile", help="AWS profile name (e.g., default)")
    ap.add_argument("--region", help="AWS region (e.g., us-east-1)")
    ap.add_argument("--dry-run", action="store_true", help="Validate parameters only")
    args = ap.parse_args()

    spec = load_yaml(args.yaml_path)
    spec.pop("Notes", None)

    # Create boto3 session
    session_args = {}
    if args.profile:
        session_args["profile_name"] = args.profile
    if args.region:
        session_args["region_name"] = args.region

    session = boto3.session.Session(**session_args)
    ec2 = session.client("ec2")

    try:
        resp = ec2.run_instances(**spec, DryRun=args.dry_run)

    except botocore.exceptions.ClientError as e:
        if args.dry_run and "DryRunOperation" in str(e):
            print("[ok] Dry-run successful; parameters are valid.")
            return
        raise

    instances = resp.get("Instances", [])
    if not instances:
        print("[warn] No Instances returned.")
        return

    inst = instances[0]
    instance_id = inst["InstanceId"]
    print(f"[ok] Launched instance: {instance_id}")

    # Wait for the instance to be running so it has a PublicIpAddress
    waiter = ec2.get_waiter("instance_running")
    print("[..] Waiting for instance to enter running state...")
    waiter.wait(InstanceIds=[instance_id])

    # Refresh details
    desc = ec2.describe_instances(InstanceIds=[instance_id])
    inst_info = desc["Reservations"][0]["Instances"][0]

    name_tag = extract_instance_name(spec)

    print(f"✅ Instance {name_tag} now running")

    public_ip = inst_info.get("PublicIpAddress")
    private_ip = inst_info.get("PrivateIpAddress")

    if public_ip:
        print(f"📡 Public IP: {public_ip}")
    if private_ip:
        print(f"🔒 Private IP: {private_ip}")

    print("👉 Add public IP address to ~/.ssh/config to support quick launch via ssh blah")
    print(f'👉 ssh -i <path_to_key> ubuntu@{public_ip} (or ec2_user@ for ARM arch)')

    yaml_filename = args.yaml_path.name
    attribute = f"{yaml_filename}({name_tag})" if name_tag else yaml_filename

    aws_log(event="ec2-launch-instance-from-yaml.py", attribute=attribute)




if __name__ == "__main__":
    main()





# """
# Minimal script to launch an EC2 instance from a YAML spec.
# To do: add user-data encoding, key-pair checks.
# """

# import argparse
# from pathlib import Path

# import boto3
# import yaml
# import botocore


# def load_yaml(path: Path) -> dict:
#     with path.open("r", encoding="utf-8") as f:
#         return yaml.safe_load(f)


# def main():
#     ap = argparse.ArgumentParser(description="Launch EC2 instance from YAML (minimal)")
#     ap.add_argument("yaml_path", type=Path, help="Path to launch YAML")
#     ap.add_argument("--profile", help="AWS profile name (e.g., default)")
#     ap.add_argument("--region", help="AWS region (e.g., us-east-1)")
#     ap.add_argument("--dry-run", action="store_true", help="Validate parameters only")
#     args = ap.parse_args()

#     spec = load_yaml(args.yaml_path)
#     spec.pop("Notes", None)

#     # Create boto3 session
#     session_args = {}
#     if args.profile:
#         session_args["profile_name"] = args.profile
#     if args.region:
#         session_args["region_name"] = args.region

#     session = boto3.session.Session(**session_args)
#     ec2 = session.client("ec2")

#     try:
#         resp = ec2.run_instances(**spec, DryRun=args.dry_run)
        
#     except botocore.exceptions.ClientError as e:
#         if args.dry_run and "DryRunOperation" in str(e):
#             print("[ok] Dry-run successful; parameters are valid.")
#             return
#         raise

#     instances = resp.get("Instances", [])
#     if not instances:
#         print("[warn] No Instances returned.")
#         return

#     inst = instances[0]
#     print(f"[ok] Launched instance: {inst['InstanceId']}")
#     if "PublicIpAddress" in inst:
#         print(f"Public IP: {inst['PublicIpAddress']}")
#     if "PrivateIpAddress" in inst:
#         print(f"Private IP: {inst['PrivateIpAddress']}")


# if __name__ == "__main__":
#     main()


