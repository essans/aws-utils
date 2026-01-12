## AWS Utils -- Wrapper script for 1-shot launch and setup of EC2 instance

This is less of a step-3 and more of how to combine step-1 and -2. So, this section essentially describes how to go from a single config files that can handle all steps of launching and configuring an EC2 instance in one go via a single wrapper script. This is useful for quickly spinning up new instances, configuring the environments so that are ready to use with minimal manual intervention.

It takes advantage of the modularity of the tools seen in the previous steps.

### Overview and how-to-use

`ec2_launch_bootstrap.py` is a wrapper script that does the following:

- Loads instance details from top section of ~/aws-utils/bootstrap/config.yaml
- Confirms current price is less than max specified using `ec2_price.zsh`
- Launches instance from matching template YAML using `ec2_launch_from_yaml.py`
- Runs `scp` command to copy bootstrap script files to remote machine
- sends via `ssh` the `run.sh` command and relevant --args which launches in a tmux session on the remote machine

eg:
```sh

ec2_launch_bootstrap.py ~/aws-utils/bootstrap/config.yaml -i

# -i for interactive mode to prompt before scp and before ssh`

```

