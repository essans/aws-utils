## AWS Utils -- Initial Set-up Instructions

This section provides step-by-step instructions to set up your local environment, and aws policies.


### System stuff, environment set-up etc

__(0) git clone this repo into your home directory__

```sh
cd ~

git clone git@github.com:essans/aws-utils.git
```

---
<br>

__(1) Install AWS CLI v2 if not already installed__
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html 

Then configure with credentials

---
<br>

__(2) Local environment setup (assumes MacOS)__

(i) create a python virtual environment and activate it.
vscode settings.json assumes ~/environment/venv

```
pip install -e .
pip install -e ."[dev]" if needed

chmod +x ~/aws-utils/scripts/*

```

<br>

(ii) Add a single line to your shell rc file. The repo ships `shellrc.sh`, which
works in both bash (Linux) and zsh (macOS) -- it sets `AWS_UTILS`, `DEVICE` and
`AWSLOGS` (creating `~/logs/aws` if missing), puts `scripts/` on `PATH`, defines
the shared `aws_log` helper, and sources every function file.

macOS -- add to `~/.zshrc`:

```sh
# --- AWS UTILS SET-UP ----
source ~/aws-utils/shellrc.sh
```

Linux -- add the same line to `~/.bashrc`:

```sh
# --- AWS UTILS SET-UP ----
source ~/aws-utils/shellrc.sh
```

`shellrc.sh` locates the repo from its own path, so the clone does not have to
live at `~/aws-utils`; adjust the `source` line to wherever you cloned it.

(iii) Next, `source` the file to load the settings. eg.

```sh
source ~/.zshrc     # macOS
source ~/.bashrc    # Linux
```

Run `ec2_show_functions` to list what got loaded.

<br>


(iv) Create a file `~/.ssh/aws_utils_defaults.yaml` to store default SSH key and git repo settings.  Example file below:

```yaml
default:
  github:
    name: Your Name
    org: repos_org_name
    email: your.email@example.com
    default_key: github #stored in ~/.ssh/

  aws:
    default_key: default_ed25519
```

(v) Make any necessary updates in `~/aws-utils/configs/user_configs.py`:

```python
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]

SCRIPTS_DIR = PROJECT_ROOT / "scripts"
CONFIG_DIR = PROJECT_ROOT / "config"
BOOTSTRAP_DIR = PROJECT_ROOT / "bootstrap"

OUTPUTS_DIR = PROJECT_ROOT / "outputs"
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)


# ===== Update here: =====
SSH_KEYS_DIR = Path.home() / ".ssh"
REPO_DEFAULTS = SSH_KEYS_DIR / "aws_utils_defaults.yaml"
USER_TO_USE = "default"

# ===== Tailscale script not yet implemented =====
TAILSCALE_CREDENTIAL_FILE = Path.home() / ".credentials" / "credentials_tailscale"
TAILSCALE_KEY_TO_USE =  "default"
```


---
<br>

__(3) Assumption is that you are already using AWS/EC2 and that you have the following already setup:__

-  vpc, subnet ids, security group ids etc
-  Also requires an IamInstanceProfile which is "container" for an IAM role that you can attach to an EC2 instance. This allows the instance to assume the permissions of the IAM role, enabling it to access AWS services securely without embedding (and potentially exposing) actual credentials. See the aws console for more info on how to set-up.

__(4) Set a policy (or policies) in AWS console per the following:__

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeRouteTables",
                "ec2:DescribeImages",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumeStatus",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:DeleteTags",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateKeyPair",
                "ec2:CreateTags",
                "ec2:CreateSecurityGroup",
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:ListAllMyBuckets",
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "pricing:GetProducts",
                "iam:PassRole",
                "secretsmanager:CreateSecret",
                "secretsmanager:DescribeSecret",
                "secretsmanager:UpdateSecret",
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "*"
        }
    ]
}
```

_Ensure that the policy is attached to the IAM user/role you are using to run these scripts._

---<br>

__(5) Now go to the next step: [Step-1: Launch/Manage EC2 Instances](step_1_launch_manage_ec2.md)__

---

### Legacy Setup Instructions (ignore!):

(ii) Add the following to the `.bash_profile`,  `.zshrc` (or equiv) file:


```sh
# --- AWS UTILS SET-UP ----

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

# --- END AWS UTILS SET-UP ----

```

(iii) Next, `source` the file to load the settings. eg.

```sh
source ~/.zshrc
