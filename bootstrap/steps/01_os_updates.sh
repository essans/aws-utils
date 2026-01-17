#!/usr/bin/env bash

# Usual OS package updates.
# Run this once, but in unlikely event there is a reboot then SSH back in and run the same script 
# again. It will print something along the lines of "SKIP 01_os_updates (already done)" or
# will re-run the step if it didn’t finish.

# To do: 
#  - Check aws for more recent version and log that
#  - For reboot check, need to add for non-ubuntu linux flavors
#  - Try to suppress the endless stream of log events from OS updates 
#  - Support non apt-get package managers for non Ubuntu flavors

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  # Non-interactive sudo check: avoids hanging on password prompt
  if ! sudo -n true 2>/dev/null; then
    log "❌ ERROR: sudo would prompt for a password (non-interactive)."
    log "👉 Fix: use a user with passwordless sudo, or run once interactively."
    exit 1
  fi
}

# check if a reboot is required, and if so, perform it
request_reboot_if_required() {
  # Based on Ubuntu
  if [[ -f /var/run/reboot-required ]]; then
    log "👉 Reboot required detected (/var/run/reboot-required). Rebooting now..."
    sudo -n reboot
    exit 0
  fi
}

ensure_yq_installed() {
  if have yq; then
    log "yq already installed"
    return 0
  fi
  if have snap; then
    log "Installing yq via snap..."
    sudo -n snap install yq || { log "❌ ERROR: snap install of yq failed"; return 1; }
    return 0
  fi
  log "⚠️ WARNING: snap not available; yq not installed. Install yq manually or add it to dpkg/snap config."
  return 1
}



log "=== STARTING OS UPDATES ==="


require_sudo

config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

if have apt-get; then
  log "Detected apt-get. Running unattended update + upgrade..."
  export DEBIAN_FRONTEND=noninteractive # non-interactive mode for apt-get

  # Avoid dpkg prompts; keep existing configs by default
  APT_OPTS=(
    -y
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold"
  )

  log "apt-get update..."
  sudo -n apt-get update -y

  log "apt-get upgrade..."
  sudo -n apt-get upgrade "${APT_OPTS[@]}"

  log "apt-get autoremove..."
  sudo -n apt-get autoremove -y

  log "apt-get autoclean..."
  sudo -n apt-get autoclean -y

  request_reboot_if_required

else
  log "❌ ERROR: apt-get package manager not found"
  exit 2
fi


log "✅ OS package updates completed."

# Install uv (Python package manager)
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv (Python package manager)..."

  curl -Ls https://astral.sh/uv/install.sh | bash

  # Add to PATH if needed (via claude)
  # check if dir exists and that is not in current PATH
  if [ -d "$HOME/.cargo/bin" ] && ! echo "$PATH" | grep -q "$HOME/.cargo/bin"; then
    export PATH="$HOME/.cargo/bin:$PATH"
    log "Added $HOME/.cargo/bin to PATH."
  fi
else
  log "uv already installed."
fi


ensure_yq_installed || { log "❌ Cannot parse config without yq"; exit 1; }


log "🔄 ...now installing packages found in config file"

if [[ -f "$config_file" ]]; then
  log "Reading dpkg package list from $config_file..."
  
  # via claude. reads each line of dpkg section and store as list
  # and install one at a time if length of list gt-0
  readarray -t dpkg_pkgs < <(yq eval '.dpkg[]' "$config_file" 2>/dev/null || true)
  if [[ ${#dpkg_pkgs[@]} -gt 0 && -n "${dpkg_pkgs[0]}" ]]; then
    log "Installing packages: ${dpkg_pkgs[*]}"
    sudo -n apt-get install -y "${dpkg_pkgs[@]}"
  else
    log "No dpkg packages listed in $config_file."
  fi
else
  log "Config file $config_file not found; skipping dpkg package install."
fi

# Install snap packages from config.yaml
if [[ -f "$config_file" ]]; then
  log "Reading snap package list from $config_file..."
  readarray -t snap_pkgs < <(yq eval '.snap[]' "$config_file" 2>/dev/null || true)
  if [[ ${#snap_pkgs[@]} -gt 0 && -n "${snap_pkgs[0]}" ]]; then
    log "Installing packages: ${snap_pkgs[*]}"
    sudo -n snap install "${snap_pkgs[@]}"
  else
    log "No snap packages listed in $config_file."
  fi
else
  log "Config file $config_file not found; skipping snap package install."
fi

log "================================"
log "✅ Package install(s) completed."
log "================================"

log ""
log "=== ▶️ === "
log ""