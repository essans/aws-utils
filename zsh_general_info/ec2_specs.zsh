# Functions to fetch EC2 instance specifications using AWS CLI.
#
# Usage:
#   ec2_specs <instance-type>   # Show specs for a specific instance type
#   ec2_specs                   # List specs for all instance types
#
# Requires jq installed for JSON parsing
#
# Designed and tested to work in mac zsh
      
ec2_specs() {
  local fam="${1:-t}"
  local vcpus="$2"
  local pattern="${fam}*"
    
  # Build filters array
  local filters=( "Name=instance-type,Values=${pattern}")
  if [[ -n "$vcpus" ]]; then
    filters+=( "Name=vcpu-info.default-vcpus,Values=${vcpus}" )
  fi
        
  aws ec2 describe-instance-types \
    --filters "${filters[@]}" \
    --query "InstanceTypes[*].{
      Type:InstanceType,
      CurrentGen: CurrentGeneration,
      Arch: join(',', ProcessorInfo.SupportedArchitectures),
      CpuCores:VCpuInfo.DefaultCores,
      CpuThreadsPerCore:VCpuInfo.DefaultThreadsPerCore, 
      VCpu:VCpuInfo.DefaultVCpus,
      GpuCount:GpuInfo.Gpus[0].Count,
      GpuName:GpuInfo.Gpus[0].Name,
      MemoryMiB:MemoryInfo.SizeInMiB,
      EbsOnly: EbsInfo.EbsOptimizedSupport,
      InstanceStorage: InstanceStorageInfo.TotalSizeInGB,
      NetPerf: NetworkInfo.NetworkPerformance,
      EbsBwMbps: EbsInfo.EbsOptimizedInfo.BaselineBandwidthInMbps,
      HasGPU: GpuInfo != null
    }" \
    --output table
}

#EbsMaxBwMbps: EbsInfo.EbsOptimizedInfo.MaximumBandwidthInMbps


# Old
#ec2-specs-ebs() {
#  local fam="${1:-t}"
#  local pattern="${fam}*"
    
#  aws ec2 describe-instance-types \
#    --filters "Name=instance-type,Values=${pattern}" "Name=current-generation,Values=true" \
#    --query "InstanceTypes[*].{
#      Type:InstanceType,
#      VCpu:VCpuInfo.DefaultVCpus,
#      MemoryMiB:MemoryInfo.SizeInMiB,
#      Arch: join(',', ProcessorInfo.SupportedArchitectures),
#      EbsOnly: EbsInfo.EbsOptimizedSupport
#    }" \
#    --output table
#}



