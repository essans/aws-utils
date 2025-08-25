## aws

### Overview
#### Collection of AWS utilities, mostly in bash and python

### System stuff, environment set-up etc

__(1) Install AWS CLI v2 if not already installed__
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html 

Then configure with your credentials

__(2) Requirements and permissions__

```
pip install -r requirements.txt

chmod +x /scripts/*

```

### Environment set-up
__`.bash_profile` or `.zshrc` file should look something like:__

```
AWS_UTILS=$HOME/aws-utils
export DEVICE=$(hostname -s)

export PATH="$AWS_UTILS/scripts:$PATH"


#############################
# AWS FUNCTIONS AND ALIASES #
#############################


for file in "$AWS_UTILS"/zsh_general_info/*.zsh; do
  source "$file"
done


for file in "$AWS_UTILS"/zsh_my_instances/*.zsh; do
  source "$file"
done


function ec2_show_functions() {
echo "-----------------"
    for file in "$AWS_UTILS"/zsh_general_info/*.zsh; do
    echo $file
    done
echo " "

    for file in "$AWS_UTILS"/zsh_my_instances/*.zsh; do
    echo $file
    done
echo "----------------"
}
```

`source` the file or restart terminal


__Set policies in AWS console to allow the following actions:__
```
"ec2:DescribeInstances",
"ec2:DescribeInstanceTypes",
"ec2:DescribeInstanceAttribute",
"ec2:DescribeInstanceStatus",
"ec2:DescribeVpcs",
"ec2:DescribeSubnets",
"ec2:DescribeRouteTables",
"ec2:DescribeSecurityGroups",
"ec2:DescribeNetworkAcls",
"ec2:DescribeVolumes",
"ec2:DescribeVolumeStatus",
"ec2:DescribeImages",
"ec2:StartInstances",
"ec2:StopInstances",
"ec2:DeleteTags"
"ec2:RunInstances",
"ec2:TerminateInstances",
"ec2:AuthorizeSecurityGroupIngress",
"ec2:RevokeSecurityGroupIngress",
"ec2:CreateKeyPair",
"ec2:CreateTags",
"ec2:CreateSecurityGroup",
"pricing:GetProducts"
```

---

### What's in here?

`ec2_show_functions` - lists all functions and aliases available

---

### Getting info on AWS services etc

(1) `my_ip` - shows your current public IP address

(2) `ec2_describe_instance_type <instance>` - shows details of a given instance type
```
ec2_describe_instance_type g4dn.2xlarge
```
<br>

(3) `ec2_images_ubuntu <arch> <version>` - shows latest Ubuntu AMI for given architecture type and version
```
ec2_images_ubuntu amd64 22
ec2_images_ubuntu arm64 20
```
<br>

(4) `ec2_specs <instance pattermn> <vcpus-optionsl` - shows specs of a given instance type with optional vCPU filter
```
ec2_specs g
ec2_specs g4dn 4
```
<br>

(5) `ec2_price <instance>` - shows on-demand pricing for a given instance type
```
ec2_price g4dn.2xlarge
```
<br>

(6) `ec2_price2 <instance>` - alternate method to handle capacity blocks causing `ec_price` to return no price
```
ec2_price2 p5.4xlarge
```
<br>

(7) `ec2_specs_price.py` -- get specs and pricing for all instance types pattern matching given string and prices
```
ec2_specs_price.py --help

usage: 
ec2_specs_price.py [-h] [--fam FAM] [--pattern PATTERN] [--vcpus VCPUS] [--region REGION] [--profile PROFILE] [--save SAVE] [--silent] [--price]

optional arguments:
  -h, --help         show this help message and exit
  --fam FAM          Instance family/prefix. Pattern is "<fam>*" (default: t).
  --pattern PATTERN  Override the wildcard pattern (e.g., "g5.*"). If set, --fam is ignored.
  --vcpus VCPUS      Optional exact vCPU filter (e.g., 16).
  --region REGION    AWS region (overrides your default/profile).
  --profile PROFILE  AWS profile name to use.
  --save SAVE        filename to save CSV in aws/outputs
  --silent           Print the DataFrame.
  --price            If set, add On-Demand Linux hourly price column.
```
eg:
```
ec2_specs_price.py --fam "g"
ec2_specs_price.py --pattern "g4dn" --price --save "g4dn.csv" 
```
<br>

---

### Info and actions relating to my specific instances and AWS services

(1) `ec2_my_instances` - shows all your EC2 instances with key details

(2) `ec2_start <instance-tag>`, `ec2_stop <instance-tag>`, `ec2_terminate <instance-tag>`- start/stop/terminate a given EC2 instance
```
ec2_start bridge
ec2_stop bridge
ec2_terminate bridge
```
<br>

(3) `ec2_get_sg_rules <instance_tag>` - shows inbound and outbound rules for security group attached instance
```
ec2_get_sg_rules bridge
```
<br>

(4) `ec2_allow_my_ip <instance_tag> <optional ip/cidr address>` - adds inbound rules to sg attached to instance to allow current IP address on ports 22 and 8888 for tcp.  Note that other instances using the same sg will also be affected. 
```
ec2_allow_my_ip bridge
ec2_allow_my_ip bridge 100.200.300.400/32 
```
<br>

(5) `ec2_revoke_my_ip <instance-tag>` - revokes inbound rules to sg attached to instance to remove current IP address on ports 22 and 8888 for tcp. Note that other instances using the same sg will also be affected. 
```
ec2_revoke_my_ip bridge
ec2_revoke_my_ip bridge 100.200.300.400/32
```
<br>

---

### Launching instances

__(1) Create a new key pair if needed:__
```
aws ec2 create-key-pair \
  --key-name default_ed25519 \
  --key-type ed25519 \
  --key-format pem \
  --query 'KeyMaterial' \
  --output text > default_ed25519.pem
```

Then:
<br>

```
chmod 400 default_ed25519.pem>
```
<br>

__(2a) Update default values in YAML spec file if needed__
`launch/t4g_nano_8gb_ubuntu_2204_ARM.yaml` <br>
(example spec file for t4g.nano ARM instance with Ubuntu 22.04 and 8GB volume)

__or(2b) Copy and modify an existing YAML spec file from `launch/` folder__

```
cp launch/t4g_nano_8gb_ubuntu_2204_ARM.yaml my_instance.yaml
```
<br>

__(3) Create new security group if needed and update YAML spec file__

View existing security groups:
```
aws ec2 describe-security-groups --output json
```
<br>

Create new security group:
```
ec2_create_sg "<sg_name>" "sg_description" "<vpc_id>"
```
<br>

__(4) Launch from YAML spec file:__

(1) `ec2_launch_from_yaml.py <yaml-file-path>` - launches an EC2 instance from a given YAML spec file
```
ec2_launch_from_yaml.py t4g_nano_8gb_ubuntu_2204_ARM.yaml
```
<br>


### In case needed:

__Describe available VPCs__
```
aws ec2 describe-vpcs \
  --query "Vpcs[*].{ID:VpcId, Name:Tags[?Key=='Name']|[0].Value, CIDR:CidrBlock,State:State, IsDefault:IsDefault}" \
  --region us-east-1 \
  --output table

aws ec2 describe-vpcs --region us-east-1 --output json

will use default region from ~/.aws/config if not specified
```

<br>

__Describe available subnets__
```
aws ec2 describe-subnets \
  --query "Subnets[*].{ID:SubnetId, VpcId:VpcId, CIDR:CidrBlock, AZ:AvailabilityZone, MapPublicIpOnLaunch:MapPublicIpOnLaunch, State:State}" \
  --output table

aws ec2 describe-subnets --output json
```

__Security groups__
```
aws ec2 describe-security-groups --output json
```
<br>

__Create new security group__
```
SG_ID=$(aws ec2 create-security-group \
  --group-name "sg_name" \
  --description "sg description" \
  --vpc-id "vpc-0abc123def456" \
  --query 'GroupId' \
  --output text)

echo "Created Security Group: $SG_ID"

aws ec2 create-tags \
  --resources "$SG_ID" \
  --tags Key=Name,Value="sg-name"
```
<br>


__Route tables__
```
aws ec2 describe-route-tables \
  --query "RouteTables[*].{ID:RouteTableId, VpcId:VpcId, Associations:Associations}"
```
<br>


__Network ACLs__
```
aws ec2 describe-network-acls --output table
```
<br>