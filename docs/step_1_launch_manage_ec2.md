## AWS Utils -- Launch and Manage EC2 Instances

This section provides an overview of the various command-line utilities available to launch and manage EC2 instances. The below assumes you have already completed the initial set-up steps outlined in [Step-0: Overview and Initial Set-up Instructions](step_0_overview_setup.md).  If successfull you should be able to run commands such as `ec2_blah_functions` from your terminal.

### (1) Overview of Utilities

`ec2_show_functions` - lists all functions and aliases available

---

### (2) Getting info on AWS services etc

`my_ip` - shows your current public IP address

`ec2_my_instances` - shows all your EC2 instances (if you have any) with key details

---

`ec2_describe_instance_type <instance>` - shows details of a given instance type

```
ec2_describe_instance_type g4dn.2xlarge
```
<br>

`ec2_images_ubuntu <arch> <version>` - shows latest Ubuntu AMI for given architecture type and version

`ec2_images_dlami <arch> <free text>` - shows latest Deep Learning AMIs for given architecture type

```
ec2_images_ubuntu amd64 22
ec2_images_ubuntu arm64 20

ec2_images_dlami amd64 PyTorch
ec2_images_dlami amd64 "PyTorch 2.8"

```
<br>

`ec2_specs <instance pattermn> <vcpus-optionsl` - shows specs of a given instance type with optional vCPU filter
```
ec2_specs g
ec2_specs g4dn 4
```
<br>

`ec2_price <instance>` - shows on-demand pricing for a given instance type

`ec2_price2 <instance>` - alternate method to handle capacity blocks causing `ec2_price` to return no price

```
ec2_price g4dn.2xlarge
ec2_price2 p5.4xlarge
```
<br>

`ec2_specs_price.py` -- get specs and pricing for all instance types pattern matching given string and prices

```
ec2_specs_price.py --help

usage: 
ec2_specs_price.py [-h] [--fam FAM] [--pattern PATTERN] [--vcpus VCPUS] 
                      [--region REGION] [--profile PROFILE] [--save SAVE] 
                      [--silent] [--price]

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

### (3) Info and actions relating to *existing* instances and AWS services

`ec2_my_instances` - shows all your EC2 instances with key details including tags

`ec2_start <instance-tag>` 
`ec2_stop <instance-tag>`
`ec2_terminate <instance-tag>`
```
ec2_start node0
ec2_stop node0
ec2_terminate node0
```
<br>

`ec2_get_sg_rules <instance_tag>` - shows inbound and outbound rules for security group attached instance
```
ec2_get_sg_rules node0
```
<br>

`ec2_allow_ip <instance_tag> <optional ip/cidr address>` - adds inbound rules to sg attached to instance and allows current IP address on ports 22 and 8888 for tcp.  Note that other instances using the same sg will also be affected. 
```
ec2_allow_ip node0
ec2_allow_ip node0 100.200.300.400/32 
```
<br>

`ec2_revoke_ip <instance-tag> <optional ip/cidr address>` - revokes inbound rules to sg attached to instance which removes current IP address on ports 22 and 8888 for tcp. Note that other instances using the same sg will also be affected. 
```
ec2_revoke_ip node0
ec2_revoke_ip node0 100.200.300.400/32
```
<br>

---

### (4) Launching instances

Quick-start assuming all scaffolding is in place:

__Launch from YAML spec file:__

`ec2_launch_from_yaml.py <yaml-path> --name blah --storage blah ` 

Launches an EC2 instance from a given YAML spec file.

_Not including optional_ `--name` _and/or_ `--storage` _will default to values in the YAML file.  These are currently "ec2_node" for the name and either 32gb or 64gb for storage. If a name is requested that is the same as an existing instance then the launch will abort._ 

_[to-do: update so that the default names are not duplicated across templates]_

```sh
ec2_launch_from_yaml.py ~/aws-utils/launch/g/g4dn_xlarge_ubuntu_2204.yaml
      --name node0 --storage 256
```

Then follow the printed instructions to ssh into the instance.

```
✅ Instance node0 now running
📡 Public IP: 3.95.170.187
🔒 Private IP: 172.31.1.142
👉 Add public IP address to ~/.ssh/config to support quick launch via ssh blah


👉 export default_aws_key=/Users/essans/.ssh/default_ed25519 if you want to persist the 🔑


✅  ssh-add /Users/essans/.ssh/github] 🔑  - verify via ssh-add -l


📡 💾 copy set-up scripts to remote machine:
👉 scp -i /Users/essans/.ssh/default_ed25519 -r /Users/essans/aws-utils/bootstrap/ ubuntu@3.95.170.187:~/


🖥️  or login to remote machine:
👉 ssh -A -i /Users/essans/.ssh/default_ed25519 ubuntu@3.95.170.187
```
__Additional information below or move on to next step:__ [link](step_2_instance_setup.md)

---

<br>

__Pre-launch set-up steps in case needed:__

__(i) Create a new key pair if needed:__

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

__(ii) Update default values in YAML spec file if needed__
`~/aws-utils/launch/g/g4dn_xlarge_ubuntu_2204.yaml` <br>
(example spec file for g4dn.xlarge instance with Ubuntu 22.04 AMI.

__or copy and modify an existing YAML spec file from `launch/<fam>` folder__

```
cp launch/g4dn_xlarge_ubuntu_2204.yaml my_new_instance_spec.yaml
```


<br>

__(iii) Create new security group if needed and update YAML spec file__

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

__(iv) 


### (5) Other miscellaneous aws ec2 CLI commands in case needed:

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

---