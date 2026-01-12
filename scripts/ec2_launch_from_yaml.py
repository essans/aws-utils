#!/usr/bin/env python3

# chmod +x /Users/essans/aws-utils/zsh_general_info/ec2_price.zsh


# -----------------------------------------------------------------------------
# Script to launch an EC2 instance from a YAML spec.
#
# High-level overview:
#   - Reads an EC2 launch specification from a YAML file (see 'launch' directory)
#   - Optionally allows on-the-fly override of instance name and EBS volume size
#   - Added: check for existing instances with the same name to avoid duplicates
#   - Launches the instance using boto3
#   - Fetches public/private IPs and rints usueful SSH and SCP user commands.
#  
# Usage examples:
#   python ec2_launch_from_yaml.py my_instance.yaml
#   python ec2_launch_from_yaml.py my_instance.yaml --name node0 --storage 100
#   python ec2_launch_from_yaml.py my_instance.yaml --profile myprofile --region us-west-2
#   python ec2_launch_from_yaml.py my_instance.yaml --dry-run
#
# Arguments:
#  yaml_path   Path to the EC2 launch YAML spec
#   --profile  AWS profile name (optional)
#   --region   AWS region (optional)
#   --dry-run  Validate parameters only, do not launch
#   --storage  Override EBS volume size (GB)
#   --name     Override Name tag for instance and volume
#
# To do:
#   - Add user-data encoding, key-pair checks
#   - Replace reliance on configs/user_configs.py

import os, sys
import argparse
from pathlib import Path

from typing import Any

import boto3 
import yaml
import botocore
from botocore.exceptions import ClientError

CONFIGS_DIR = Path(__file__).resolve().parents[1] / "configs"
SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.append(str(SRC_DIR))
sys.path.append(str(CONFIGS_DIR))

import user_configs
from aws_logger import aws_log

PROJECT_ROOT = user_configs.PROJECT_ROOT
EVENT = "ec2-launch-instance-from-yaml.py"


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)
    
def extract_instance_name(spec: dict) -> Any:
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

def override_volume_size(spec: dict, volume_size: int) -> None:
    """Override the VolumeSize in BlockDeviceMappings."""
    if "BlockDeviceMappings" in spec:
        for bdm in spec["BlockDeviceMappings"]:
            if "Ebs" in bdm and "VolumeSize" in bdm["Ebs"]:
                bdm["Ebs"]["VolumeSize"] = volume_size

def override_tag_name(spec: dict, tag_name: str) -> None:
    """Override the Name tag in TagSpecifications for both instance and volume."""
    if "TagSpecifications" in spec:
        for ts in spec["TagSpecifications"]:
            if "Tags" in ts:
                for tag in ts["Tags"]:
                    if tag.get("Key") == "Name":
                        tag["Value"] = tag_name


def get_ini_value(file_path: Path, section: str, key: str) -> str:
    """Parse config file (INI-like format) and extract value for given section and key."""
    in_section = False
    with file_path.open('r') as f:
        for line in f:
            line = line.strip()
            # Check if we're entering the target section
            if line == f"[{section}]":
                in_section = True
                continue
            # Check if we're entering a different section
            if line.startswith('['):
                in_section = False
                continue
            # If in target section and key matches, extract value
            if in_section and '=' in line:
                k, v = line.split('=', 1)
                if k.strip() == key:
                    return v.strip()
    raise ValueError(f"Key '{key}' not found in section '[{section}]'")

def check_instance_name_exists(ec2_client: Any, instance_name: str) -> bool:
    """Check if an instance with the given name already exists."""
    try:
        response = ec2_client.describe_instances(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': [instance_name]
                },
                {
                    'Name': 'instance-state-name',
                    'Values': ['pending', 'running', 'stopping', 'stopped']
                }
            ]
        )
        
        # Check if any instances were found
        for reservation in response.get('Reservations', []):
            if reservation.get('Instances', []):
                return True
        return False
    except ClientError as e:
        print(f"❌ Error checking for existing instances: {e}", file=sys.stderr)
        sys.exit(1)



def main() -> None:
    ap = argparse.ArgumentParser(description="Launch EC2 instance from YAML (minimal)")
    ap.add_argument("yaml_path", type=Path, help="Path to launch YAML")
    ap.add_argument("--profile", help="AWS profile name (e.g., default)")
    ap.add_argument("--region", help="AWS region (e.g., us-east-1)")
    ap.add_argument("--dry-run", action="store_true", help="Validate parameters only")
    ap.add_argument("--storage", type=int, help="Override volume size in GB")
    ap.add_argument("--name", help="Override the Name tag for instance and volume")
    args = ap.parse_args()

    spec = load_yaml(args.yaml_path)
    spec.pop("Notes", None)

    # Check environment variables first (set by ec2_launch_bootstrap.py)
    default_aws_key = os.getenv('DEFAULT_AWS_KEY')
    default_github_key = os.getenv('DEFAULT_GITHUB_KEY')

    # If not set via environment, load from REPO_DEFAULTS
    if not default_aws_key or not default_github_key:
        aws_log(event=EVENT, attribute="no env keys set. Grabbing from repo defaults...")
        user_defaults_from_file_all = load_yaml(user_configs.REPO_DEFAULTS)
        user_defaults_from_file = user_defaults_from_file_all["default"]
        if not default_aws_key:
            default_aws_key = f"{user_configs.SSH_KEYS_DIR}/{user_defaults_from_file['aws']['default_key']}"
        if not default_github_key:
            default_github_key = f"{user_configs.SSH_KEYS_DIR}/{user_defaults_from_file['github']['default_key']}"
    else:
        default_aws_key = f"{user_configs.SSH_KEYS_DIR}/{default_aws_key}"
        default_github_key = f"{user_configs.SSH_KEYS_DIR}/{default_github_key}"

    # Apply overrides if provided
    if args.storage:
        override_volume_size(spec, args.storage)
    
    if args.name:
        override_tag_name(spec, args.name)

    # Create boto3 session
    session_args = {}
    if args.profile:
        session_args["profile_name"] = args.profile
    if args.region:
        session_args["region_name"] = args.region

    session = boto3.Session(**session_args) # was boto3.session.Session(blah)
    ec2 = session.client("ec2")

    # Check if instance name already exists
    instance_name = extract_instance_name(spec) or args.name
    if instance_name:
        if check_instance_name_exists(ec2, instance_name):
            print(f"❌ Error: An instance with the name '{instance_name}' already exists.", file=sys.stderr)
            print(f"👉 Choose a different name or terminate conflicting instance.", file=sys.stderr)
            sys.exit(1)

    try:
        resp = ec2.run_instances(**spec, DryRun=args.dry_run)

    except ClientError as e:
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
    print('\n')
    print(f"[ok] Launched instance: {instance_id}")
    print('\n')
    # Wait for the instance to be running so it has a PublicIpAddress
    waiter = ec2.get_waiter("instance_running")
    aws_log(event=EVENT, 
            attribute="[..] Waiting for instance to enter running state...", 
            verbose=True)
    waiter.wait(InstanceIds=[instance_id])

    # Refresh details
    desc = ec2.describe_instances(InstanceIds=[instance_id])
    inst_info = desc["Reservations"][0]["Instances"][0]

    name_tag = extract_instance_name(spec)

    print('\n')
    print(f"✅ Instance {name_tag} now running")

    public_ip = inst_info.get("PublicIpAddress")
    private_ip = inst_info.get("PrivateIpAddress")

    if public_ip:
        print(f"📡 Public IP: {public_ip}")
    if private_ip:
        print(f"🔒 Private IP: {private_ip}")


    print("👉 Add public IP address to ~/.ssh/config to support quick launch via ssh blah")
    print('\n')

    print(default_aws_key)
    print(default_github_key)
    
    print(f'👉 export default_aws_key={default_aws_key} if you want to persist the 🔑')
    print('\n')

    print(f'✅  ssh-add {default_github_key} 🔑  - verify via ssh-add -l  #ssh authentication agent')
    os.system(f'ssh-add {default_github_key}')
    print('\n')

    scp_location = user_configs.BOOTSTRAP_DIR
    print(f'📡 💾 copy set-up scripts to remote machine:')
    print(f'👉 scp -i {default_aws_key} -r {scp_location}/ ubuntu@{public_ip}:~/')
    print('\n')

    #print(f'🤖 run remotely using:')
    #print(f'👉 ssh -A -i {default_aws_key} ubuntu@{public_ip} "bash ~/bootstrap/run.sh"')
    #print('\n')

    print(f'🖥️  or login to remote machine:')
    print(f'👉 ssh -A -i {default_aws_key} ubuntu@{public_ip}') # ec2_user@ for ARM arch
    print('\n')

    yaml_filename = args.yaml_path.name
    attribute = f"{yaml_filename}({name_tag})" if name_tag else yaml_filename

    aws_log(event=EVENT, attribute=attribute)


if __name__ == "__main__":
    aws_log(event=EVENT, attribute="starting run")
    main()


