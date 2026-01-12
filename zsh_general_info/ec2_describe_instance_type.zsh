# script that wraps around aws cli function to describe an user provided instance and provides 
# pre-determind details about that instance

# written to run on a mac in zsh shell.  Not tested outside of mac

function ec2_describe_instance_type() {
    if [ -z "$1" ]; then
        echo "Error: Instance type parameter is required."
        echo "Usage: describe_instance_type <instance_type>"
        return 1
    fi

    local instance_type="$1"
  
    aws ec2 describe-instance-types \
        --query "InstanceTypes[?InstanceType=='$instance_type'].{
            InstanceType:InstanceType,
            Memory:MemoryInfo.SizeInMiB,
            CpuCores:VCpuInfo.DefaultCores,
            CpuThreadsPerCore:VCpuInfo.DefaultThreadsPerCore,  
            GpuCount:GpuInfo.Gpus[0].Count,
            GpuName:GpuInfo.Gpus[0].Name,
            Storage:InstanceStorageInfo.TotalSizeInGB,
            EBSVolumes:BlockDeviceMappings[].Ebs.VolumeId || 'None' \
        }" \
        --output table  
}


# https://aws.amazon.com/ec2/instance-types/
