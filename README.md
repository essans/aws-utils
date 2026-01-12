## aws-utils

### Overview
Collection of AWS utilities, designed to quickly launch, manage and use EC2 instances for personal projects.

### Motivations

AWS EC2 instances are a core enabler for my project work and while spinning up virtual machines using native AWS tools might be straightforward, in reality there are a head-spinning array of options and choices to be made: instance types, AMIs, EBS volumes, security groups, key pairs, VPCs, IAM roles, snapshots, and more.  

Then once an instance is running, there’s the whole post-launch configuration process: updating the OS, installing packages and tools, configuring user accounts and credentials, and so on.  

_And all this before I can even start using the instance for the actual work I care about..._ 

Given the time/effort to create and configure an instance I'm usually reluctant to terminate it, leading to unnecessary costs that accrue even when the instance is idle (eg EBS volumes, elastic IPs, etc). _This repository is my attempt to automate the process so that I can quickly build, configure, and tear-down EC2 instances as needed, without worrying about losing important configurations or code._

---

#### Step 1: [Launching EC2 Instances](docs/step_1_launch_manage_ec2.md)
With core AWS scaffolding already in place (required: VPC, subnets, security groups, IAM roles, etc.), and with a fairly limited range of EC2 instances that I care about for most use cases, the first step is to launch an EC2 instance with minimal friction. 

Step-1 consists of various bash/shell and Python command-line scripts that automate the following:
 - Find and inspect available EC2 instance types and AMIs
 - Launch an EC2 instance using a predefined configuration stored in a YAML spec
 - Start, stop, and terminate instances with a single command based on their Name tag
 - View and manage the current set of instances (whether running or stopped)
 - Manage security groups, including IP address whitelisting

This automation reduces setup overhead and makes EC2 usage fast and repeatable.  It's almost as fast as booting up a local machine and requires minimal cognitive stress.  Overview provided [here](docs/step_1_launch_manage_ec2.md).

---

#### Step-2: [Post-launch configuration](docs/step_2_instance_setup.md)

Once the instance is running, the next step kick-off machine environment set-up tasks based on a configuration file to update operating system, install packages, set-up python, aws-cli, git etc.

The goal is to perform all of this with a single command in a way that allows me to bootstrap a fresh pre-configured EC2 instance from anywhere, at any time. Whether I’m at home or travelling, I want to be fully up and running in with minimal effort so that I can get on with the real work.  Then tear it down when I'm done, knowing that I can recreate it just as easily next time.

While AWS provides native tools that can _in theory_ automate most of this, I find them unnecessarily complex and overkill for my personal use cases.  Overview provided [here](docs/step_2_instance_setup.md).

---

#### The ultimate workflow: Combine Step-1 and Step-2 in [one-shot config](docs/step_3_one_shot_launch_bootstrap.md) :)

By including information about the desired instance into the post-launch configuration YAML file used in step-2, I can combine both steps into a single seamless workflow via `python ec2_launch_bootstrap.py ~/path/to/bootstrap_config.yaml` which will:
 - Launch the EC2 instance per Step-1
 - Wait for it to become reachable via SSH
 - Copy the neccessary post-launch scripts to the remote instance
 - Run the post-launch configuration per Step-2

This is the ultimate goal of this repository: to be able to quickly and reliably launch a fully configured EC2 instance with a single command, allowing me to focus on my projects without getting bogged down in setup details.  

Once account details and confifs are established (1-time set-up) the following takes less than 5mins: <br>

 - Launch new EC2 instance and wait for it to become reachable via SSH <br>
 - Copy files to the remote instance and run the following: <br>
 - Pre-flight checks <br>
 - Update OS packages, configure python tooling/environment <br>
 - Configure git, clone some repos;  aws-cli, and some other setups <br>
 - Set-up torch and verify details where a deep-learning aws image is used <br>
 - Install and set-up claude-code <br>
 - Configure instance for web jupyter notebook access or web vscode access <br>

Overview provided [here](docs/step_3_one_shot_launch_bootstrap.md).

---

#### Getting Started
Follow the initial set-up instructions [here](docs/step_0_overview_setup.md) then proceed to [Step-1](docs/step_1_launch_manage_ec2.md), [Step-2](docs/step_2_instance_setup.md), and [Step-3](docs/step_3_one_shot_launch_bootstrap.md).

<br>

---

#### To do / Future Work
- add additional bootstrap steps (eg docker, olama, tailscale etc)
- convert .zsh scripts to .sh so that they are shell-agnostic
- extend for gcp/azure, lambda.ai 
