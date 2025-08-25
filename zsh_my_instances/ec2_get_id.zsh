

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

