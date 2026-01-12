# Functions to retrieve the SG ID and display SG rules for an EC2 instance by Name-tag.
#
# Overview:
#   - ec2_sg: Gets the security group ID for a running EC2 instance by Name tag.
#   - ec2_get_sg_rules: Looks up the security group for an instance and displays its rules in table format.
#   - Logs actions to $HOME/logs/aws/aws_cli.log.
#
# Usage:
#   ec2_sg <instance_name>            # Get the security group ID for the instance
#   ec2_get_sg_rules <instance_name>  # Show security group rules for the instance
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

 
function ec2_sg() {
    if [ -z "$1" ]; then
        echo "Error: Instance name is required."
        echo "Usage: ec2-sg <instance_name>"
        return 1
    fi
      
    local instance_name="$1"
    
    #aws ec2 describe-instances \
    #    --filters "Name=tag:Name,Values=$instance_name" \
    #    --query 'Reservations[].Instances[].[SecurityGroups]' \
    #    --output text | tr '\n' ' ' | sed 's/\t.*//'

    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[].Instances[].SecurityGroups[0].GroupId' \
        --output text

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
    echo "$sg_id"
    
    aws ec2 describe-security-groups \
        --filters "Name=group-id,Values=$sg_id" \
        --output table > $filename
        
    cat $filename
    
}   