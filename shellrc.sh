# aws-utils shell entry point -- works in both bash (Linux) and zsh (macOS).
#
# Add ONE line to ~/.bashrc (Linux) or ~/.zshrc (macOS):
#
#   source ~/aws-utils/shellrc.sh
#
# It sets the shared env vars, defines the shell-side aws_log helper, puts
# scripts/ on PATH and sources every function file in the two function dirs.
#
# Deliberately kept POSIX-ish: no arrays, no bashisms, no zsh-isms, so the same
# file is valid in bash 3.2 (stock macOS), bash 5.x (Linux) and zsh.

# --- repo location -----------------------------------------------------------
# Resolve this file's directory in whichever shell is sourcing us, so the repo
# does not have to live at ~/aws-utils.
if [ -n "${BASH_SOURCE:-}" ]; then
  AWS_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
  AWS_UTILS="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  AWS_UTILS="$HOME/aws-utils"
fi
export AWS_UTILS

# --- shared env --------------------------------------------------------------
export DEVICE="${DEVICE:-$(hostname -s)}"

# Log dir used by both the shell aws_log below and src/aws_logger.py.
# Created here so a fresh machine does not error on first use.
export AWSLOGS="$HOME/logs/aws"
[ -d "$AWSLOGS" ] || mkdir -p "$AWSLOGS"

case ":$PATH:" in
  *":$AWS_UTILS/scripts:"*) ;;
  *) export PATH="$AWS_UTILS/scripts:$PATH" ;;
esac

# --- shared helper -----------------------------------------------------------
# Single definition of the shell-side logger. Previously copy-pasted into five
# files under zsh_my_instances/. Mirrors src/aws_logger.py::aws_log.
aws_log() {
    local event="$1"
    local attribute="$2"

    echo "$(date +%Y-%m-%dT%H:%M:%S) - $event - $attribute - ${DEVICE}_$(curl -s https://checkip.amazonaws.com)/32" \
        >> "$AWSLOGS"/aws_cli.log
}

# --- load the function library ----------------------------------------------
for _aws_utils_file in "$AWS_UTILS"/zsh_general_info/*.sh "$AWS_UTILS"/zsh_my_instances/*.sh; do
  [ -r "$_aws_utils_file" ] && . "$_aws_utils_file"
done
unset _aws_utils_file

ec2_show_functions() {
  echo "-----------------"
  ls "$AWS_UTILS"/zsh_general_info/*.sh
  echo " "
  ls "$AWS_UTILS"/zsh_my_instances/*.sh
  echo "-----------------"
}
