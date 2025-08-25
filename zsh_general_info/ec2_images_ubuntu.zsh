# get ami for various images

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

# old
# function ec2_images_ubuntu_server() {
#     local itype="$1"
#     if [[ -z "$itype" ]]; then
#         echo "image description: arm64 or amd64" >&2
#         return 1
#     fi

#     aws ec2 describe-images \
#     --owners 099720109477 \
#     --filters "Name=name,Values=ubuntu/images/hvm-ssd*/ubuntu-*-$itype-server-*" \
#                 "Name=state,Values=available" \
#     --query 'Images | sort_by(@,&CreationDate) | reverse(@)[].
#             {CreationDate: CreationDate, Name: Name, ImageId: ImageId}' \
#     --output table

# }