
# List amazon-owned Deep Learning AMIs (DLAMI) but calling aws api for describe images
# Designed and tested to work on a mac in zsh

# Usage:
#   ec2_images_dlami [arch] [filter]
#     arch   : arm64 | amd64 (optional; defaults to all)
#     filter : free-text to match in name, e.g. pytorch|tensorflow|base|gpu|ubuntu (optional)
# Examples:
#   ec2_images_dlami                # all DLAMIs by Amazon
#   ec2_images_dlami amd64          # x86_64 only
#   ec2_images_dlami arm64 ubuntu   # arm64 Ubuntu DLAMIs
#   ec2_images_dlami amd64 pytorch  # x86_64 PyTorch DLAMIs
#


    function ec2_images_dlami() {
      local arch_input="$1"   # arm64 | amd64 | empty
      local name_filter="$2"  # substring to match in Name

      # Map user-friendly arch to AWS EC2 architecture values
      local arch_value=""
      if [[ -n "$arch_input" ]]; then
        case "$arch_input" in
          arm64) arch_value="arm64" ;;
          amd64|x86_64) arch_value="x86_64" ;;
          *)
            echo "arch must be one of: arm64 | amd64" >&2
            return 1
            ;;
        esac
      fi

      # Build name pattern. All DLAMIs contain the prefix "Deep Learning AMI".
      local name_pattern="Deep Learning*"
      if [[ -n "$name_filter" ]]; then
        name_pattern="*Deep Learning*${name_filter}*"
      fi

      # Assemble filters
      local filters=(
        "Name=name,Values=${name_pattern}"
        "Name=state,Values=available"
      )
      if [[ -n "$arch_value" ]]; then
        filters+=("Name=architecture,Values=${arch_value}")
      fi

      aws ec2 describe-images \
        --owners amazon \
        --filters "${filters[@]}" \
        --query 'Images | sort_by(@,&CreationDate) | reverse(@)[].{CreationDate: CreationDate, Name: Name, ImageId: ImageId, Architecture: Architecture}' \
        --output table
    }
