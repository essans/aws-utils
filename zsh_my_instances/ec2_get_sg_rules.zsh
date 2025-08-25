

function aws_log() {
    local event="$1"
    local attribute="$2"
 
    echo $(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - "$DEVICE"_$(curl -s https://checkip.amazonaws.com)/32 >> "$AWSLOGS"/aws_cli.log
  
} 

 
function ec2_sg() {
    if [ -z "$1" ]; then
        echo "Error: Instance name is required."
        echo "Usage: ec2-sg <instance_name>"
        return 1
    fi
      
    local instance_name="$1"
    
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[].Instances[].[SecurityGroups]' \
        --output text | tr '\n' ' ' | sed 's/\t.*//'
}
 
 
function ec2_get_sg_rules() {

    filename="$AWSLOGS"/ec2-sg-rules_$1.$(date +%Y-%m-%dT%H:%M:%S)
    
    if [ -z "$1" ]; then
        echo "Error: Instance name is required."
        echo "Usage: ec2-sg-rules <instance_name>"
        return 1
    fi
      
    local instance_name="$1"
    local sg_id
    
    sg_id=$(ec2_sg "$instance_name")
    
    aws ec2 describe-security-group-rules \
        --filters "Name=group-id,Values=$sg_id" \
        --output table > $filename
        
    cat $filename
    
}   