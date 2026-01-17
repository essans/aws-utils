#!/usr/bin/env bash

# Configures instance for AWS CLI v2 incl. a basic ~/.aws/config file.
# Intentionally does not install/write any credentials but relies on IAM roles specified in machine config

# To do:
# - For simplicity is there a "safe" way to transport the .aws/credentials file? (and not need IAM role)

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    log "❌ ERROR: sudo would prompt for password (non-interactive required)."
    exit 1
  fi
}

log "=== STARTING AWS SETUP ==="


ensure_apt() {
  have apt-get || { log "❌ ERROR: apt-get not found."; exit 2; }
}

ensure_apt_pkg() {
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1 || sudo -n apt-get install -y "$pkg"
}

awscli_is_v2() {
  have aws || return 1
  aws --version 2>&1 | grep -q "aws-cli/2"
}

install_or_update_awscli_v2() {
  require_sudo
  ensure_apt

  log "Checking for prerequisites..."
  sudo -n apt-get update -y
  ensure_apt_pkg curl
  ensure_apt_pkg unzip

  local tmpdir zipfile
  tmpdir="$(mktemp -d)"
  zipfile="$tmpdir/awscliv2.zip"

  log "Downloading AWS CLI v2 installer..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$zipfile"

  log "Unzipping installer..."
  unzip -q "$zipfile" -d "$tmpdir"

  log "Installing/updating AWS CLI v2..."
  sudo -n "$tmpdir/aws/install" --update

  rm -rf "$tmpdir"
}

# Write basic ~/.aws/config file (no credentials)
config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"
echo "$config_file"
write_aws_config() {
  local config_yaml=$config_file
  local region output profile

  profile=$(yq '.aws.profile' "$config_yaml")
  region=$(yq '.aws.region' "$config_yaml")
  output="json"
  
  local pager="${AWS_PAGER_DEFAULT:-}"

  mkdir -p "$HOME/.aws"
  chmod 700 "$HOME/.aws"

  local cfg="$HOME/.aws/config"

  # Build config content
  log "Writing ~/.aws/config..."
  {
    echo "[${profile}]"
    echo "region = ${region}"
    echo "output = ${output}"
    # Via claude, disable pager by default for non-interactive
    if [[ -n "$pager" ]]; then
      echo "cli_pager = ${pager}"
    else
      echo "cli_pager ="
    fi
    # Also via claude an optional consistent retry mode
    echo "retry_mode = standard"
    echo "max_attempts = 10"
  } > "$cfg"  # send output to config file

  chmod 600 "$cfg" 
}

print_post_checks() {
  log "AWS CLI version:"
  aws --version || true

  log "Current AWS config:"
  if [[ -f "$HOME/.aws/config" ]]; then
    sed 's/^/  /' "$HOME/.aws/config"  #via claude indent each line by 2 spaces
  else
    log "  (no config file found)"
  fi

  log "Checking IAM identity with 'aws sts get-caller-identity':"
  if aws sts get-caller-identity --output json 2>/dev/null; then
    log "IAM identity is associated with this instance."
  else
    log "⚠️ WARNING: No IAM identity detected or insufficient permissions."
  fi

  log "NOTE:"
  log "  - This relies on IAM instance roles for the EC2 instance to provide AWS credentials."
  log "  - run: aws configure (interactive) OR write ~/.aws/credentials to set up credentials manually."
}

log "=== Step 04: AWS CLI v2 + ~/.aws/config ==="

# Install/update AWS CLI v2 if needed
if awscli_is_v2; then
  log "AWS CLI v2 already installed."
else
  log "AWS CLI v2 not found (or v1 detected). Installing/updating..."
  install_or_update_awscli_v2
fi

# Write config (safe, no secrets)
write_aws_config

# Quick sanity check (won't fail the step if no permissions)
print_post_checks


log "======================"
log "✅ AWS set-up complete"
log "======================"

log ""
log "=== ▶️ === "
log ""