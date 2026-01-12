# Function to get the EC2 instance id for a given name/tag.
#
# Overview:
#   - Looks up running EC2 instances by Name tag and returns their instance IDs.
#   - Outputs one or more instance IDs as a space-separated string.
#
# Usage:
#   ec2_get_id <instance_name>
#     <instance_name>: Required. The Name tag of the EC2 instance(s).
#
# Requirements:
#   - AWS CLI configured
#   - macOS zsh environment



function ec2_get_id() {
    if [ -z "$1" ]; then
        echo "Error: Instance name is required."
        echo "Usage: ec2-id <instance_name>"
        return 1
    fi
      
    local instance_name="$1"
    
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[].Instances[].[InstanceId]' \
        --output text | tr '\n' ' ' | sed 's/ *$//g'
}

