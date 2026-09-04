# quick function for getting current instances and details in the current authenticated aws account
#
# Usage:
#   ec2_my_instances [--json]
#     --json: Output JSON instead of the default table (easier to read on mobile,
#             and pipeable into jq).

function ec2_my_instances() {

    local filename="$AWSLOGS"/ec2-describe-my-instances.$(date +%Y-%m-%dT%H:%M:%S)

    local output="table"
    local projection="Reservations[*].Instances[*]"

    while [ $# -gt 0 ]; do
        case "$1" in
            --json)
                output="json"
                # flatten so json is a single list of instances rather than a list of lists
                projection="Reservations[].Instances[]"
                ;;
            -h|--help)
                echo "Usage: ec2_my_instances [--json]"
                return 0
                ;;
            *)
                echo "Error: unknown option: $1"
                echo "Usage: ec2_my_instances [--json]"
                return 1
                ;;
        esac
        shift
    done

    aws ec2 describe-instances \
        --query "${projection}.{ \
            PublicIP:PublicIpAddress, \
            PrivateIP:PrivateIpAddress, \
            Instance:InstanceId, \
            AZ:Placement.AvailabilityZone, \
            Group:Placement.GroupName, \
            Type:InstanceType, \
            Name:Tags[?Key==\`Name\`] | [0].Value, \
            Status:State.Name, \
            Subnet:SubnetId, \
            SecurityGroup:SecurityGroups[0].GroupId, \
            EBSVolumes:join(',', BlockDeviceMappings[].Ebs.VolumeId) \
        }" \
        --output "$output"

}
