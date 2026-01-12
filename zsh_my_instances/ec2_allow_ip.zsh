# Function to authorize current public IP (or a specified one) for SSH (22) and Jupyter (8888)
# on the security group of a running EC2 instance by Name tag.
#
# Overview:
#   - Looks up the security group for a running EC2 instance by Name tag.
#   - Authorizes ingress for your current public IP (or a provided CIDR) on ports 22 and 8888.
#   - Logs actions and errors to $HOME/logs/aws/aws_cli.log.
#
# Usage:
#   ec2_allow_ip <Instance-Name-Tag> [cidr]
#     <Instance-Name-Tag>: Required. The Name tag of the running EC2 instance.
#     [cidr]: Optional. CIDR to allow (default: your current public IP/32).
#
# Requirements:
#   - AWS CLI configured
#   - jq installed for JSON parsing
#   - macOS zsh environment


AWSLOGS=$HOME/logs/aws

function aws_log() {
    local event="$1"
    local attribute="$2"
 
    echo $(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - "$DEVICE"_$(curl -s https://checkip.amazonaws.com)/32 >> "$AWSLOGS"/aws_cli.log
  
} 


function ec2_allow_ip() {
  local INSTANCE_NAME="$1"
  local cidr

  if [[ -n "$2" ]]; then
    cidr="$2"
  else
    # Otherwise, fetch the current public IP and append /32
    local my_ip
    my_ip="$(curl -s https://checkip.amazonaws.com)"
    cidr="${my_ip}/32"
  fi

  if [[ -z "$INSTANCE_NAME" ]]; then
    echo "Usage: ec2_allow_my_ip <Instance-Name-Tag> [cidr]"
    return 1
  fi

  # Look up the Security Group ID from the instance name
  local SG_ID
  SG_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].SecurityGroups[].GroupId" \
    --output text)

  if [[ -z "$SG_ID" || "$SG_ID" == "None" ]]; then
    echo "❌ Could not find a running instance with Name=$INSTANCE_NAME"
    return 1
  fi

  echo "[ok] Authorizing $cidr on SG=$SG_ID for tcp on ports 22 and 8888"

  # SSH (22)
  out22=$(aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$cidr" 2>&1)

if echo "$out22" | grep -qi 'error'; then
  echo "❌ Error authorizing tcp/22: $out22"
  aws_log "ec2-allow-error" "${INSTANCE_NAME}-${cidr}-22"
else
  echo "✅ Opened tcp/22 for $cidr on $SG_ID"
  aws_log "ec2-allow-success" "${INSTANCE_NAME}-${cidr}-22"
fi
  

  # Jupyter (8888)
 out8888=$(aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 8888 \
    --cidr "$cidr" 2>&1)

if echo "$out8888" | grep -qi 'error'; then
  echo "❌ Error authorizing tcp/8888: $out8888"
  aws_log "ec2-allow-error" "${INSTANCE_NAME}-${cidr}-8888"
else
  echo "✅ Opened tcp/8888 for $cidr on $SG_ID"
  aws_log "ec2-allow-success" "${INSTANCE_NAME}-${cidr}-8888"
fi

  local event=ec2-allow-my-ip
  local attribute="${INSTANCE_NAME}-${cidr}"
  aws_log "$event" "$attribute"

}

  




# old

# function ec2_allow_my_ip() {
#   local INSTANCE_NAME="$1"
#   if [[ -z "$INSTANCE_NAME" ]]; then
#     echo "Usage: ec2_allow <Instance-Name-Tag>"
#     return 1
#   fi
    
#   # Look up the Security Group ID from the instance Name tag
#   local SG_ID
#   SG_ID=$(aws ec2 describe-instances \
#     --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
#               "Name=instance-state-name,Values=running" \
#     --query "Reservations[].Instances[].SecurityGroups[].GroupId" \
#     --output text)
    
#   if [[ -z "$SG_ID" ]]; then
#     echo "❌ Could not find a running instance with Name=$INSTANCE_NAME"
#     return 1
#   fi
    
#   # Get current public IPv4
#   local MY_IP
#   MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '\n')/32"
  
#   echo "🔐 Authorizing $MY_IP for port 22 on SG=$SG_ID"
  
#   # SSH (22)
#   aws ec2 authorize-security-group-ingress \
#     --group-id "$SG_ID" \
#     --protocol tcp \
#     --port 22 \
#     --cidr "$MY_IP" || true

# echo "🔐 Authorizing $MY_IP for port 8888 on SG=$SG_ID"

#   # Jupyter (8888)
#   aws ec2 authorize-security-group-ingress \
#     --group-id "$SG_ID" \
#     --protocol tcp \
#     --port 8888 \
#     --cidr "$MY_IP" || true
# }
