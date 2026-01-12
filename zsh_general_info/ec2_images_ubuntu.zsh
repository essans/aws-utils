#
# Script to retrieve aws AMI IDs for Ubuntu images using aws cli.
#   - Filters by architecture (arm64 or amd64) and optional Ubuntu version.
#   - Lists images owned by Canonical (owner ID: 099720109477).
#   - Outputs a table with creation date, name, and image ID, sorted by newest.
#
# Usage:
#   ec2_images_ubuntu <arm64|amd64> [version]
#     <arm64|amd64>: Required. Architecture type.
#     [version]:     Optional. Ubuntu version (e.g., 22.04). If omitted, all versions.
#
# Examples:
#   ec2_images_ubuntu amd64
#   ec2_images_ubuntu arm64 22.04

# Designed and tested to run in mac zsh

function ec2_images_ubuntu() {
    local itype="$1"
    local ver="$2"

    if [[ -z "$itype" ]]; then
        echo "usage: ec2_images_ubuntu_server <arm64|amd64> [version]" >&2
        return 1
    fi

    # If version not provided, match all
    local version_pattern="*"
    if [[ -n "$ver" ]]; then
        version_pattern="${ver}.*"
    fi

    aws ec2 describe-images \
      --owners 099720109477 \
      --filters \
        "Name=name,Values=ubuntu/images/hvm-ssd*/ubuntu-*-${version_pattern}-${itype}-*-*" \
        "Name=state,Values=available" \
      --query 'Images | sort_by(@,&CreationDate) | reverse(@)[].
              {CreationDate: CreationDate, Name: Name, ImageId: ImageId}' \
      --output table
}
