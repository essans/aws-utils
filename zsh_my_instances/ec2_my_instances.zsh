# quick function for getting current instances and details in the current authenticated aws account

function ec2_my_instances() {
        
    local filename="$AWSLOGS"/ec2-describe-my-instances.$(date +%Y-%m-%dT%H:%M:%S)
        
    aws ec2 describe-instances \
        --query "Reservations[*].Instances[*].{ \
            PublicIP:PublicIpAddress, \
            PrivateIP:PrivateIpAddress, \
            Instance:InstanceId, \
            AZ:Placement.AvailabilityZone, \
            Group:Placement.GroupName, \
            Type:InstanceType, \
            Name:Tags[?Key==\`Name\`] | [0].Value, \
            Status:State.Name \
            Subnet:SubnetId \
            SecurityGroup:SecurityGroups[0].GroupId \
            EBSVolumes:join(',', BlockDeviceMappings[].Ebs.VolumeId) \
        }" \
        --output table
    
}