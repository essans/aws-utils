AWSLOGS=$HOME/AWS-UTILS/logs

function aws_log() {
    local event="$1"
    local attribute="$2"
 
    echo $(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - "$DEVICE"_$(curl -s https://checkip.amazonaws.com)/32 >> "$AWSLOGS"/aws_cli.log
  
} 


function ec2_allow_my_ip() {
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
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$cidr" || true

  echo "✅ opened tcp on ports 22"

  # Jupyter (8888)
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 8888 \
    --cidr "$cidr" || true

  echo "✅ opened tcp on ports 22"

  local event=ec2-allow-my-ip
  local attribute="${instance_name}-${cidr}"
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
