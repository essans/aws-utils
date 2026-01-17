## AWS Utils -- Post-launch configuration

This section provides an overview of the post-launch configuration steps to set up a newly launched EC2 instance. The below assumes you have already completed the initial set-up steps outlined in [Step-0: Overview and Initial Set-up Instructions](step_0_overview_setup.md) and have launched an EC2 instance as per [Step-1: Launch and Manage EC2 Instances](step_1_launch_manage_ec2.md).  If successful you should have a running EC2 instance that you can SSH into.

---

### Overview of Post-launch Configuration

Once the instance is running, the next step is to automate common post-launch configuration tasks:
 - Update operating system packages
 - Install standard tools (e.g., Git, Docker, Python)
 - Configure user accounts and credentials (Git, Docker Hub, etc.)

This achieves the goal of near-automation via a single command. Everything is version-controlled in GitHub, allowing for the bootstrapping of a fresh EC2 instance from anywhere, at any time. Once the I want to be fully up and running in under five minutes o that I can get on with the real work.

While AWS provides native tools to automate most of this, I find them unnecessarily complex and overkill for my personal use cases.

---

#### How to use
(1) Launch EC2 instance from YAML spec file. 

(2) For machine set-up the various settings/preferences stored in a [config_template.yaml](../bootstrap/config_template.yaml). Not only does this file store various configuration options (e.g. git username, email, repos to clone, etc) but also controls which steps are run during the post-launch configuration.  See details below and in the file for details.

(3) `scp` the post-launch script and associated files to the remote machine and run it via ssh (or ssh in and run it from there).  

```sh
scp -i ~/.ssh/mykey.pem -r ~/aws-utils/bootstrap/ ubuntu@${EC2_IP}:~/
ssh - A -i ~/.ssh/mykey.pem ubuntu@${EC2_IP} "bash ~/bootstrap/run.sh --config.yaml --run"

```

Notes:
- Different config.yaml files can created and used as project-specific templates.  E.g. config.yaml can be the generic or base template while config_g4dn.yaml can be a set of configs specifically relevant for a gpu type instance. These can be passed into the `run.sh` script via `--config <file>`

- `run-sh` takes addition args such as `--skip-steps 02,03` to skip certain steps etc.  See below

- Progress logged in ~/bootstrap/bootstrap.log on the remote machine

(4) Once done, ssh into the machine and start using it! or connect via vscode remote-ssh extension, etc.

---

#### Details, Flexibility, Extensibility

The post-launch script and associated files are modular and extensible, meaning steps can be added or modified without breaking the whole thing.  For example if I want to add a step to install and configure docker, I can just add a new `10_docker.sh` script and whoich will be called from the main `run.sh` driver script.

```
bootstrap/
  config.yaml
  run.sh
  steps/
    00_preflight.sh
    01_os_updates.sh
    02_git_etc.sh
    03_system_python.sh
    04_mamba_python_tooling.sh
    05_venv_python_tooling.sh
    06_aws.sh
    07_other_setups.sh
    08_dlami_torch_verify.sh
    09_claude_code.sh
    10_ide_setup.sh   
    11_torch_setup.sh
```

- Each `steps/NN_name.sh` is one unit of work.
- `run.sh` handles logging, stamping, ordering, and reboot-resume.
- See header of each script file for more info

---
<br>

__run.sh overview and usage:__

`run.sh --config <file> --skip nn,mm, only pp,qq --run --dry-run, --force`

```
Options:
  --config <file>     Path to config.yaml (default: $HOME/bootstrap/config.yaml)
  --skip 01,05,08     Skip steps by numeric prefix (comma/space-separated)
  --only 00,02        Run only these step numbers (comma/space-separated)
  --dry-run           Show what would run; do not execute or write stamps (default)
  --run               Actually execute steps (disables dry-run)
  --force             Run steps even if already stamped-as-done
  --help              Show help

Notes:
  - By default, the script runs in dry-run mode for safety. Use --run to execute steps.
  - Step files must be named like NN_name.sh (e.g., 00_preflight.sh).
  - --only takes precedence by skipping everything not listed.
  - Stamps are written to $HOME/bootstrap/.stamps/ to track completed steps. ie. run.sh is "idempotent" which means it can be re-run safely without redoing work unless --force is used to override.
  - The pipeline will also stop with an error if any step fails (see ~/bootstrap/bootstrap.log for details).
```

__Next section brings together steps 1 and 2:__ [link](step_3_one_shot_launch_bootstrap.md)

---
