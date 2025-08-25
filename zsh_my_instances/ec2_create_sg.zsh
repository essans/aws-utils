AWSLOGS=$HOME/AWS-UTILS/logs

function aws_log() {
    local event="$1"
    local attribute="$2"
 
    echo $(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - "$DEVICE"_$(curl -s https://checkip.amazonaws.com)/32 >> "$AWSLOGS"/aws_cli.log
  
} 


# Create (or reuse) a Security Group and tag it with a Name
# Usage:
#   ec2_create_sg "my-sg-name" "My SG description" "vpc-0123abcd..."
#
# Returns: prints the SG_ID to stdout

ec2_create_sg() {
  local SG_NAME="$1"
  local SG_DESC="$2"
  local VPC_ID="$3"

  # Check if an SG with this name already exists in the VPC
  local EXISTING_ID
  EXISTING_ID=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=${SG_NAME}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)

  if [[ -n "$EXISTING_ID" && "$EXISTING_ID" != "None" ]]; then
    SG_ID="$EXISTING_ID"
  else
    # Create the SG
    SG_ID=$(aws ec2 create-security-group \
      --group-name "$SG_NAME" \
      --description "$SG_DESC" \
      --vpc-id "$VPC_ID" \
      --query 'GroupId' \
      --output text)
  fi

  # Add a Name tag
  aws ec2 create-tags \
    --resources "$SG_ID" \
    --tags Key=Name,Value="$SG_NAME"

  echo "$SG_ID"
}