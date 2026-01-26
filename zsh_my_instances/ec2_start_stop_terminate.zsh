# Functions to start, stop, and terminate EC2 instances by name tag using AWS CLI under-the-hood
#
# Overview:
#   - ec2_start <instance_name>:     Start an EC2 instance by Name tag, wait for running, show IPs, and print SSH tips.
#   - ec2_stop <instance_name>:      Stop an EC2 instance by Name tag.
#   - ec2_terminate <instance_name>: Terminate an EC2 instance by Name tag, remove Name tag, and wait for termination.

#   - Uses ec2_get_id helper to resolve instance IDs from Name tags.
#   - Logs actions to $HOME/logs/aws/aws_cli.log.
#
# Usage:
#   ec2_start <instance_name>
#   ec2_stop <instance_name>
#   ec2_terminate <instance_name>
#
# Requirements:
#   - AWS CLI configured
#   - macOS zsh environment

AWSLOGS=$HOME/logs/aws
 
    
function aws_log() {
    local event="$1"
    local attribute="$2"
 
    echo $(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - "$DEVICE"_$(curl -s https://checkip.amazonaws.com)/32 >> "$AWSLOGS"/aws_cli.log
  
} 

# see/update standalone file for source 
function ec2_get_id() {
    if [ -z "$1" ]; then
        echo "❌ Error: Instance name is required."
        echo "👉 Usage: ec2-id <instance_name>"
        return 1
    fi
      
    local instance_name="$1"
    
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[].Instances[].[InstanceId]' \
        --output text | tr '\n' ' ' | sed 's/ *$//g'
}


function ec2_start() {
  if [ -z "$1" ]; then
    echo "❌ Error: Instance name is required."
    echo "👉 Usage: ec2_start <instance_name>"
    return 1
  fi

  local instance_name="$1"
  local instance_id
  instance_id="$(ec2_get_id "$instance_name")" || return 1

  echo "[..] Starting $instance_name ($instance_id)…"
  aws ec2 start-instances --instance-ids "$instance_id" >/dev/null

  # Wait until the instance is in 'running' state
  echo "[..] Waiting for instance to enter 'running' state…"
  aws ec2 wait instance-running --instance-ids "$instance_id"

  # Refresh details and pull IPs
  local public_ip private_ip
  public_ip="$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)"

  private_ip="$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)"

  echo "[ok] Instance is running."
  if [[ "$public_ip" != "None" ]]; then
    echo "📡 Public IP:  $public_ip"
  fi
  if [[ "$private_ip" != "None" ]]; then
    echo "Private IP: $private_ip"
  fi

  local event=ec2-start-instance
  local attribute="${instance_name}-${instance_id}"
  aws_log "$event" "$attribute"

  # Helpful SSH tip
  echo
  echo "👉Add public IP to ~/.ssh/config for quick SSH (optional). Example:"
  echo "  Host ${instance_name}"
  echo "    HostName ${public_ip:-$private_ip}"
  echo "    User ubuntu   # Ubuntu images use 'ubuntu'; Amazon Linux uses 'ec2-user'"
  echo "    IdentityFile /path/to/your/key.pem"
  echo
  if [[ "$public_ip" != "None" ]]; then
    echo "👉Quick connect:"
    echo "  ssh -i /path/to/your/key.pem ubuntu@${public_ip}"
    echo "  # For Amazon Linux images, use:"
    echo "  ssh -i /path/to/your/key.pem ec2-user@${public_ip}"
  else
    echo "[note] No public IP detected. Ensure your subnet/ENI has AssociatePublicIpAddress=true,"
    echo "       or connect via private IP + VPN/DirectConnect, or use SSM Session Manager."
  fi
}

    
    
function ec2_stop() {
        if [ -z "$1" ]; then
        echo "❌ Error: Instance name is required."
        echo "👉 Usage: ec2-stop <instance_name>"  
        return 1
        fi
          
    local instance_name="$1"
    local instance_id
    
    instance_id=$(ec2_get_id "$instance_name")
    
    aws ec2 stop-instances --instance-ids "$instance_id"
    
    local event=ec2-stop-instance
    local attribute="$instance_name"_"$instance_id"
    aws_log $event $attribute
    
}   


function ec2_terminate() {
  if [[ -z "$1" ]]; then
    echo "❌ Error: Instance name is required."
    echo "👉 Usage: ec2-terminate <instance_name>"
    return 1
  fi

  local instance_name="$1"
  local instance_id

  instance_id="$(ec2_get_id "$instance_name")" || {
    echo "❌ Error: Failed to resolve instance ID for name: $instance_name"
    return 1
  }

  if [[ -z "$instance_id" ]]; then
    echo "❌ Error: No instance found with Name tag: $instance_name"
    return 1
  fi

  if [[ "$(wc -w <<<"$instance_id")" -ne 1 ]]; then
    echo "❌ Error: Multiple instances matched Name '$instance_name': $instance_id"
    return 1
  fi

  #echo "[..]Termination initiated for $instance_name ($instance_id)."
  #echo "[..]Removing Name tag from $instance_id ..."
  #if ! aws ec2 delete-tags --resources "$instance_id" --tags Key=Name >/dev/null; then
  #  echo "⚠️ Warning: Could not remove Name tag (insufficient perms or already absent). Continuing…"
  #fi

  echo "Terminating instance $instance_id ..."
  if ! aws ec2 terminate-instances --instance-ids "$instance_id" >/dev/null; then
    echo "Error: terminate-instances failed for $instance_id"
    return 1
  fi

  echo "[..]Waiting for instance to reach 'terminated' state..."
  aws ec2 wait instance-terminated --instance-ids "$instance_id" || {
    echo "❌ Warning: Waiter failed or timed out."
  }

  echo "✅ Successfully terminated '$instance_name': $instance_id"

  local event="ec2-terminate-instance"
  local attribute="${instance_name}_${instance_id}"
  aws_log "$event" "$attribute"

}





# Old
# function ec2_start() {
#         if [ -z "$1" ]; then
#         echo "Error: Instance name is required."
#         echo "Usage: ec2-start <instance_name>" 
#         return 1
#         fi
          
#     local instance_name="$1"
#     local instance_id
    
#     instance_id=$(ec2_get_id "$instance_name")
    
#     aws ec2 start-instances --instance-ids "$instance_id"
    
#     local event=ec2-start-instance
#     local attribute="$instance_name"-"$instance_id"
    
#     aws_log $event $attribute
    
# }   