#!/usr/bin/env python3

# chmod +x /Users/essans/aws-utils/zsh_general_info/ec2_price.zsh


# Wrapper script to quickly launch and bootstrap an EC2 instance based on a config file:
#  - Loads instance details from bootstrap/config*.yaml
#  - Confirms current price is < max using ec2_price.zsh
#  - Launches instance from matching template YAML using ec2_launch_from_yaml.py
#  - scp's the required bootstrap script files and config to remote machine
#  - sends command to execute inside a tmux sesssion on remote machine
#
#  usage:
#    ec2_launch_bootsrap <path/to/bootstrap-config-yaml> [-i optionally for interactive]
# -i option will prompt prior to copying and executing on remote machine

import argparse
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import yaml

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.append(str(SRC_DIR))
SH_SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "zsh_general_info"

from aws_logger import aws_log

EVENT = "EC2_launch_bootstrap"

def load_config(config_path: str) -> dict:
    """Load config from yaml file"""
    
    config_file = Path(config_path).expanduser()
    if not config_file.exists():
        #print(f"Error: Config file not found: {config_file}", file=sys.stderr)
        aws_log(event=EVENT, 
                attribute=f"❌ Error: Config file not found: {config_file}", verbose=True)
        sys.exit(1)

    with open(config_file, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    return config


def find_launch_template(instance_config: dict) -> str:
    """Find matching launch template based on instance config"""
    
    instance_type = instance_config["type"].replace(".", "_")
    ubuntu_version = str(instance_config["ubuntu"]).replace(".", "")
    dlami_required = instance_config.get("dlami", "N").upper() == "Y"

    launch_dir = Path(__file__).parent.parent / "launch" / instance_config["family"]
    if not launch_dir.exists():
        aws_log(event=EVENT, 
                attribute=f"❌ Error: Launch directory not found: {launch_dir}", verbose=True)

        sys.exit(1)

    for template_file in launch_dir.glob("*.yaml"):
        filename = template_file.name

        if not filename.startswith(instance_type):
            continue

        ubuntu_suffix = f"ubuntu_{ubuntu_version}.yaml"
        if not filename.endswith(ubuntu_suffix):
            continue

        has_dlami = "dlami" in filename
        if dlami_required and not has_dlami:
            continue  # Need DLAMI but file doesn't have it
        if not dlami_required and has_dlami:
            continue  # Don't need DLAMI but file has it

        # Found a match
        return str(template_file)

    dlami_str = "DLAMI_" if dlami_required else ""
    template_pattern = f"{instance_type}*{dlami_str}*ubuntu_{ubuntu_version}.yaml"
    aws_log(event=EVENT, 
            attribute=f"❌ Error: No launch template found matching: {template_pattern}", verbose=True)
    print(f"Searched in: {launch_dir}", file=sys.stderr)
    sys.exit(1)


def check_instance_price(instance_type: str, max_price: float) -> bool:
    """Check current EC2 instance price"""
    
    script_dir = SH_SCRIPTS_DIR
    ec2_price_script = script_dir / "ec2_price.zsh"

    if not ec2_price_script.exists():
        aws_log(event=EVENT, 
                attribute=f"❌ Error: ec2_price.zsh not found: {ec2_price_script}", verbose=True)
        sys.exit(1)

    try:
        cmd = f"source {ec2_price_script} && ec2_price {instance_type}"
        result = subprocess.run(
            ["zsh", "-c", cmd],
            capture_output=True,
            text=True,
            check=True
        )
        output = result.stdout.strip()
        if not output:
            aws_log(event=EVENT, 
                attribute=f"❌ Error: No output from ec2_price.zsh", verbose=True)

            sys.exit(1)
        current_price = float(output)
        
    except subprocess.CalledProcessError as e:
        aws_log(event=EVENT, 
                attribute=f"❌ Error running ec2_price.zsh: {e.stderr}", verbose=True)

        sys.exit(1)
    except ValueError:
        aws_log(event=EVENT, 
                attribute=f"❌ Error: Could not parse price '{output}' from ec2_price.zsh", 
                verbose=True)

        sys.exit(1)

    if current_price > max_price:
        
        aws_log(event=EVENT, 
                attribute=f"⚠️ Error: Current price ${current_price:.4f}/hr exceeds max ${max_price:.4f}/hr", 
                verbose=True)

        return False

    aws_log(event=EVENT, 
                attribute=f"✅ Price check passed: ${current_price:.4f}/hr < ${max_price:.4f}/hr", 
                verbose=True)

    aws_log(event=EVENT, attribute=f'current_price:{current_price}')
    return True


def wait_for_ssh(host: str, port: int = 22, timeout: int = 300, interval: int = 5) -> bool:
    """Wait for SSH to be available on the remote instance."""
    
    aws_log(event=EVENT, 
                attribute=f"🔄 Waiting for SSH service to be ready on {host}...", 
                verbose=True)
    
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex((host, port))
            sock.close()
            
            if result == 0:
                print(f"✓ SSH service is ready on {host}")
                return True
        except (socket.gaierror, socket.error):
            pass
        
        time.sleep(interval)
    
    aws_log(event=EVENT, 
                attribute=f"⚠️ Timeout waiting for SSH service on {host}", 
                verbose=True)

    
    return False


def launch_instance(template_path: str, instance_name: str, storage_size: int, config_path: str, interactive: bool = False) -> None:
    """Execute ec2_launch_from_yaml.py with the appropriate inputs"""
    
    script_dir = Path(__file__).parent
    launch_script = script_dir / "ec2_launch_from_yaml.py"

    if not launch_script.exists():
        aws_log(event=EVENT, 
                attribute=f"❌ Error: ec2_launch_from_yaml.py not found: {launch_script}", 
                verbose=True)

        sys.exit(1)

    # Load config to extract git SSH key
    config = load_config(config_path)
    github_key = config.get('git', {}).get('ssh_key')
    if not github_key:
        aws_log(event=EVENT, 
                attribute="⚠️ Warning: git.ssh_key not found in config", 
                verbose=True)
    
    # Load template to extract KeyName (AWS key)
    with open(template_path, 'r') as f:
        template = yaml.safe_load(f)
    aws_key = template.get('KeyName')
    if not aws_key:
        aws_log(event=EVENT, 
                attribute="⚠️ Warning: KeyName not found in launch template", 
                verbose=True)
    
    # Set environment variables for the subprocess
    env = dict(os.environ)
    if github_key:
        env['DEFAULT_GITHUB_KEY'] = github_key
    if aws_key:
        env['DEFAULT_AWS_KEY'] = aws_key

    cmd = [
        str(launch_script),
        template_path,
        "--name", instance_name,
        "--storage", str(storage_size)
    ]

    aws_log(event=EVENT, 
                attribute=f"🔄 Launching instance: {instance_name}", 
                verbose=True)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,
            env=env
        )
        
        if result.returncode != 0:
            aws_log(event=EVENT, 
                    attribute="❌ Error: Failed to launch instance", 
                    verbose=True)
            aws_log(event=EVENT, attribute=f'cmd: {cmd}')
            aws_log(event=EVENT, attribute=f'stdout: {result.stdout}')
            aws_log(event=EVENT, attribute=f'stderr: {result.stderr}')
            sys.exit(1)
        
        output_lines = result.stdout.split("\n")
        scp_command = None
        ssh_key = None
        public_ip = None
        
        # Parse output
        for line in output_lines:
            if "Public IP:" in line:
                public_ip = line.split("Public IP:")[-1].strip()
            
            elif "scp -i" in line:
                scp_command = line.strip()
                if scp_command.startswith("👉"):
                    scp_command = scp_command[2:].strip()
                
                if "-i" in scp_command:
                    parts = scp_command.split()
                    key_idx = parts.index("-i")
                    if key_idx + 1 < len(parts):
                        ssh_key = parts[key_idx + 1]
        
        # Give some time for SSH to be ready before attempting file copy
        if public_ip and not wait_for_ssh(public_ip):
            aws_log(event=EVENT, 
                attribute="⚠️ Warning: SSH service not ready, skipping file operations", 
                verbose=True)

            print("\n" + result.stdout)
            return
        
        if scp_command:
            execute_scp = True
            if interactive:
                response = input("\n👉 Copy bootstrap files to instance? [Y/n]: ").strip().lower()
                execute_scp = response in ["", "y", "yes"]
            
            if execute_scp:
                # Add StrictHostKeyChecking option when not in interactive mode
                if not interactive:
                    scp_command = scp_command.replace("scp -i", "scp -o StrictHostKeyChecking=no -i")
                
                print("\n")
                aws_log(event=EVENT, 
                    attribute=f"🔄 Copying bootstrap files to instance...", 
                    verbose=True)

                print(f"⚙️  Executing: {scp_command}")
                aws_log(event=EVENT, 
                    attribute=f"⚙️  Executing: {scp_command}", 
                    verbose=True)

                scp_result = subprocess.run(
                    scp_command,
                    shell=True,
                    check=False
                )

                if scp_result.returncode == 0:
                    aws_log(event=EVENT, 
                        attribute=f"✅ Bootstrap files copied successfully", 
                        verbose=True)
                    
                    # Copy GitHub SSH key to the instance for git operations
                    if github_key and ssh_key:
                        github_key_path = Path.home() / ".ssh" / github_key
                        if github_key_path.exists():
                            scp_key_cmd = f"scp -o StrictHostKeyChecking=no -i {ssh_key} {github_key_path} ubuntu@{public_ip}:~/.ssh/{github_key}"
                            aws_log(event=EVENT, 
                                attribute=f"🔑 Copying GitHub SSH key to instance...", 
                                verbose=True)
                            key_result = subprocess.run(scp_key_cmd, shell=True, check=False)
                            if key_result.returncode == 0:
                                # Set correct permissions and configure SSH to use the key for GitHub
                                ssh_config_cmd = [
                                    "ssh", "-o", "StrictHostKeyChecking=no", "-i", ssh_key,
                                    f"ubuntu@{public_ip}",
                                    f"chmod 600 ~/.ssh/{github_key} && "
                                    f"echo -e 'Host github.com\\n  IdentityFile ~/.ssh/{github_key}\\n  IdentitiesOnly yes' >> ~/.ssh/config && "
                                    f"chmod 600 ~/.ssh/config"
                                ]
                                subprocess.run(ssh_config_cmd, check=False)
                                aws_log(event=EVENT, 
                                    attribute=f"✅ GitHub SSH key configured on instance", 
                                    verbose=True)
                            else:
                                aws_log(event=EVENT, 
                                    attribute=f"⚠️ Warning: Failed to copy GitHub SSH key", 
                                    verbose=True)
                        else:
                            aws_log(event=EVENT, 
                                attribute=f"⚠️ Warning: GitHub key not found at {github_key_path}", 
                                verbose=True)

                else:
                    print("⚠️ Warning: scp command failed", file=sys.stderr)
                    aws_log(event=EVENT, 
                        attribute=f"⚠️ Warning: scp command failed", 
                        verbose=True)

            else:
                print("Skipped copying bootstrap files")

        else:
            aws_log(event=EVENT, 
                        attribute="⚠️ Warning: Could not find scp command in output", 
                        verbose=True)

        
        # Execute remote bootstrap script if we have IP and key
        if public_ip and ssh_key:
            config_name = Path(config_path).stem
            ssh_args = ["ssh", "-A", "-t"]  # -t forces pseudo-terminal allocation for tmux
            if not interactive:
                ssh_args.extend(["-o", "StrictHostKeyChecking=no"])
            ssh_args.extend(["-i", ssh_key, f"ubuntu@{public_ip}"])

            tmux_session = "bootstrap"
            bootstrap_cmd = f"bash ~/bootstrap/run.sh --config ~/bootstrap/{config_name}.yaml --run"
            # GitHub SSH key is copied to the instance, no agent forwarding needed inside tmux
            remote_cmd = f"cd ~ && tmux new-session -d -s {tmux_session} '{bootstrap_cmd}'"

            ssh_command = ssh_args + [remote_cmd]

            execute_remote = True
            if interactive:
                response = input("\n👉 Execute bootstrap script on remote instance? [Y/n]: ").strip().lower()
                execute_remote = response in ["", "y", "yes"]
            
            if execute_remote:
                aws_log(event=EVENT, 
                        attribute=f"\n⚙️ Executing bootstrap script on remote instance...", 
                        verbose=True)

                aws_log(event=EVENT, 
                        attribute=f"🔄 Running: {' '.join(ssh_command)}", 
                        verbose=True)

                ssh_result = subprocess.run(ssh_command, check=False)
                if ssh_result.returncode == 0:
                    aws_log(event=EVENT, 
                        attribute="✅ Bootstrap script launched in tmux session", 
                        verbose=True)

                    if public_ip and ssh_key:
                        print(f"\n👉 To monitor the bootstrap process, run:")
                        print(f"   ssh -A -i {ssh_key} ubuntu@{public_ip}")
                        print(f"   tmux attach-session -t {tmux_session}")
                        print(r'   or tail -f ~/bootstrap/bootstrap.log | grep "\[2026"')

                else:
                    aws_log(event=EVENT, 
                        attribute="⚠️ Warning: Failed to launch bootstrap script", 
                        verbose=True)
                
            else:
                print("Skipped remote bootstrap execution")
        else:
            aws_log(event=EVENT, 
                        attribute="⚠️ Warning: Could not extract IP or SSH key for remote execution", 
                        verbose=True)

            
        # Print remaining output
        print("\n" + result.stdout)
        
    except subprocess.CalledProcessError:
        aws_log(event=EVENT, 
                        attribute="❌ Error: Failed to launch instance --", 
                        verbose=True)

        aws_log(event=EVENT, attribute=f'cmd: {cmd}')
        sys.exit(1)


def main() -> None:
    aws_log(event=EVENT, attribute="running main() ======================================")
    parser = argparse.ArgumentParser(
        description="Launch and bootstrap an EC2 instance from YAML configuration"
    )
    parser.add_argument("config", help="Path to configuration YAML file")
    parser.add_argument("-i", "--interactive", action="store_true", 
                        help="Prompt for confirmation before scp and remote execution")

    args = parser.parse_args()

    # Load configuration
    config = load_config(args.config)
    ec2_config = config.get("ec2_instance", {})
    aws_log(event=EVENT, attribute = args.config)

    # Validate required fields
    required_fields = ["type", "max_price", "name", "ebs_storage", "ubuntu"]
    for field in required_fields:
        if field not in ec2_config:
            aws_log(event=EVENT, 
                        attribute=f"❌ Error: Missing required config field: ec2_instance.{field}", 
                        verbose=True)
            sys.exit(1)

    aws_log(event=EVENT, attribute="validated configuration file")

    print(f"🔄 Loading configuration from {args.config}")
    print(f"Instance type: {ec2_config['type']}, Max price: ${ec2_config['max_price']}/hr")

    # Find launch template
    template_path = find_launch_template(ec2_config)
    print(f"✅ Found launch template: {Path(template_path).name}")
    aws_log(event=EVENT, attribute = template_path)

    # Check price
    if not check_instance_price(ec2_config["type"], ec2_config["max_price"]):
        sys.exit(1)

    # Launch instance
    launch_instance(
        template_path,
        ec2_config["name"],
        ec2_config["ebs_storage"],
        args.config,
        args.interactive
    )

if __name__ == "__main__":
    main()
