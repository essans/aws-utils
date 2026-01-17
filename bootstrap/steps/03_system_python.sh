#!/usr/bin/env bash

# Set-up system python

# To do:
#  - Is this even needed? Can we rely on whatever Ubuntu gives us out-of-the-box ?

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    log "❌ ERROR: sudo would prompt for password (non-interactive required)."
    exit 1
  fi
}

ensure_apt() {
  have apt-get || { log "❌ ERROR: apt-get not found."; exit 2; }
}

ensure_yq() {
  have yq || { log "❌ ERROR: yq not found. Install with: sudo apt-get install -y yq"; exit 3; }
}

ensure_apt_pkg() {
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1 || sudo -n apt-get install -y "$pkg"
}

# suggeted by claude
pipx_ensure_path() {
  # pipx puts binaries in ~/.local/bin typically
  if [[ ":${PATH}:" != *":$HOME/.local/bin:"* ]]; then
    log "NOTE: $HOME/.local/bin is not in PATH for this session."
    log "May need to restart shell or add it to profile."
  fi
  # best effort: pipx ensurepath may update shell rc files
  pipx ensurepath >/dev/null 2>&1 || true
}

pipx_install_if_missing() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    log "$tool already installed"
    return 0
  fi
  log "Installing $tool via pipx..."
  pipx install "$tool"
}

log "=== STARTING SYSTEM PYTHON SETUP ==="


ensure_apt
ensure_yq
require_sudo

sudo -n apt-get update -y

# Parse python version/ppa from config.yaml with safe fallbacks
# Tested for and support use of python 3.7 even in ubuntu 24.04 which i need for legacy stuff
config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

python_version="default"
python_ppa=""
PYTHON_BIN="python3"

if [[ -f "$config_file" ]]; then
  if have yq; then
    python_version=$(yq -r '.python.version // "default"' "$config_file" 2>/dev/null || echo "default")
    python_ppa=$(yq -r '.python.ppa // ""' "$config_file" 2>/dev/null || echo "")
  else
    log "yq not installed; falling back to default system python3"
  fi
else
  log "Config file $config_file not found; using default system python3"
fi

# check if python version is specified. Otherwise use system default
if [[ "$python_version" == "default" || -z "$python_version" || "$python_version" == "null" ]]; then
  log "Using default system python3"
  ensure_apt_pkg python3
  ensure_apt_pkg python3-venv
  ensure_apt_pkg python3-pip
  ensure_apt_pkg pipx
  PYTHON_BIN="python3"
else
  log "Attempting to install python$python_version"

  # If a PPA is provided, add it before installing (eg I have deadsnakes in config for older versions)
  if [[ -n "$python_ppa" && "$python_ppa" != "null" ]]; then
    # Make a bit resilient
    if [[ "$python_ppa" == "deadsnake" || "$python_ppa" == "deadsnake/ppa" ]]; then
      log "Normalizing PPA name deadsnake -> deadsnakes/ppa"
      python_ppa="deadsnakes/ppa"
    fi

    log "Adding PPA $python_ppa for python$python_version"
    ensure_apt_pkg software-properties-common # suggested by claude
    if sudo -n add-apt-repository -y "ppa:$python_ppa"; then
      sudo -n apt-get update -y
    else
      log "Failed to add PPA $python_ppa; proceeding without it"
    fi
  fi

  if sudo -n apt-get install -y "python$python_version" "python$python_version-venv" "python$python_version-distutils" "python$python_version-pip"; then
    PYTHON_BIN="python$python_version"
    log "Successfully installed python$python_version"
  else
    log "Install with python$python_version-pip failed; retrying without distro pip package"
    if sudo -n apt-get install -y "python$python_version" "python$python_version-venv" "python$python_version-distutils"; then
      PYTHON_BIN="python$python_version"
      log "Installed python$python_version without distro pip; bootstrapping pip via ensurepip"
      "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1 || true
    else
      log "Failed to install python$python_version, falling back to default system python3"
      ensure_apt_pkg python3
      ensure_apt_pkg python3-venv
      ensure_apt_pkg python3-pip
      ensure_apt_pkg pipx
      PYTHON_BIN="python3"
    fi
  fi
fi


# update pip
python3 -m pip install --upgrade pip >/dev/null 2>&1 || true

log "Configuring pipx..."
pipx_ensure_path

# Add ~/.local/bin to PATH for this session
export PATH="$HOME/.local/bin:$PATH"
log "Added ~/.local/bin to PATH for current session"

# Install common dev tools as isolated apps
pipx_install_if_missing uv

# Install additional pipx packages from config_file
if [[ -f "$config_file" ]]; then
  log "Reading pipx package list from $config_file..."
  readarray -t pipx_lines < <(yq eval '.pipx[]' "$config_file" 2>/dev/null || true)
  if [[ ${#pipx_lines[@]} -gt 0 && -n "${pipx_lines[0]}" ]]; then
    log "Installing pipx packages..."
    for line in "${pipx_lines[@]}"; do
      # Extract package name (first word) for checking if installed
      pkg_name=${line%% *}
      if command -v "$pkg_name" >/dev/null 2>&1; then
        log "$pkg_name already installed"
      else
        log "Installing $line via pipx..."
        pipx install $line
      fi
    done
  else # error handling suggested by claude
    log "No pipx packages listed in $config_file."
  fi
else
  log "Config file $config_file not found; skipping pipx package install."
fi

log "==============================="
log "✅ System Python setup complete"
log "==============================="

log ""
log "=== ▶️ === "
log ""