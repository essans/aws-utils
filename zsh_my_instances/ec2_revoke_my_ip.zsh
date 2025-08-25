AWSLOGS=$HOME/AWS-UTILS/logs

function aws_log() {
    local event="$1"
    local attribute="$2"
 
    echo $(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - "$DEVICE"_$(curl -s https://checkip.amazonaws.com)/32 >> "$AWSLOGS"/aws_cli.log
  
} 


function ec2_revoke() {
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
    
  # Look up all Security Groups attached to this instance
  local SG_IDS
  SG_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].SecurityGroups[].GroupId" \
    --output text)
    
  if [[ -z "$SG_IDS" ]]; then
    echo "❌ Could not find a running instance with Name=$INSTANCE_NAME"
    return 1
  fi
     
  echo "🚫 Revoking $MY_IP on port 22 SG(s): $SG_IDS"
  
  for SG_ID in $SG_IDS; do
    # SSH (22)
    aws ec2 revoke-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp \
      --port 22 \
      --cidr "$MY_IP" || true

  echo "🚫 Revoking $MY_IP on port 8888 SG(s): $SG_IDS"

    # Jupyter (8888)
    aws ec2 revoke-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp \
      --port 8888 \
      --cidr "$MY_IP" || true
      
  echo "🚫 Revoking 0.0.0.0/0 on port 22 SG(s): $SG_IDS"

    aws ec2 revoke-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp \
      --port 22 \
      --cidr 0.0.0.0/0

  local event=ec2-revoke-my-ip
  local attribute="${instance_name}-${cidr}"
  aws_log "$event" "$attribute"
  done
  
  }


