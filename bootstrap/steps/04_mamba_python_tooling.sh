#!/usr/bin/env bash

# Set-up mamba.  If this exectutes then the venv step if requested will be skipped to avoid conflicts

# To do:
#  - 



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

# suggested by claude
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



install_miniforge3() {
  if command -v mamba >/dev/null 2>&1 || command -v micromamba >/dev/null 2>&1; then
    log "mamba or micromamba already installed"
    return 0
  fi
  
  log "Installing miniforge3..."
  local miniforge_url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
  local installer_path="/tmp/Miniforge3-Linux-x86_64.sh"
  
  log "Downloading miniforge3 installer from $miniforge_url"
  if ! curl -fsSL "$miniforge_url" -o "$installer_path"; then
    log "❌ ERROR: Failed to download miniforge3 installer"
    return 1
  fi
  
  log "Running miniforge3 installer..."
  # Remove existing installation if it exists to force clean reinstall
  if [[ -d "$HOME/miniforge3" ]]; then
    log "Removing existing miniforge3 installation at $HOME/miniforge3..."
    rm -rf "$HOME/miniforge3"
  fi
  if ! bash "$installer_path" -b -p "$HOME/miniforge3"; then
    log "❌ ERROR: Failed to install miniforge3"
    return 1
  fi
  
  log "Cleaning up installer..."
  rm -f "$installer_path"
  
  # Initialize mamba/conda shell
  log "Initializing mamba shell..."
  "$HOME/miniforge3/bin/conda" init bash 2>/dev/null || log "⚠️  Failed to init bash"
  "$HOME/miniforge3/bin/conda" init zsh 2>/dev/null || log "⚠️  Failed to init zsh"
  
  # Disable auto-activation of base environment
  log "Disabling auto-activation of base environment..."
  "$HOME/miniforge3/bin/conda" config --set auto_activate_base false
  
  log "✅ miniforge3 installed successfully at $HOME/miniforge3"
}


log "=== STARTING MAMBA SETUP ==="

ensure_apt
ensure_yq
require_sudo

sudo -n apt-get update -y

if ! command -v mamba >/dev/null 2>&1 && ! command -v micromamba >/dev/null 2>&1; then
  install_miniforge3
else
  log "⚠️  mamba or micromamba already installed, skipping installation"
fi

# Extract mamba configuration from config file
config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

mamba_env=$(yq -r '.python.mamba_env // "default"' "$config_file" 2>/dev/null || echo "default")
mamba_python_version=$(yq -r '.python.mamba_python_version // "3.11"' "$config_file" 2>/dev/null || echo "3.11")

log "Mamba environment: $mamba_env, Python version: $mamba_python_version"

# Source miniforge3 initialization if mamba not in PATH
if ! command -v mamba >/dev/null 2>&1; then
  log "Sourcing miniforge3 initialization..."
  if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
    source "$HOME/miniforge3/etc/profile.d/conda.sh"
  fi
fi

# Create mamba environment if it doesn't exist
if conda env list | grep -q "^$mamba_env "; then
  log "Mamba environment '$mamba_env' already exists"
else
  log "Creating mamba environment '$mamba_env' with Python $mamba_python_version..."
  mamba create -y -n "$mamba_env" "python=$mamba_python_version"
fi

# Activate the mamba environment
log "Activating mamba environment '$mamba_env'..."
conda activate "$mamba_env"

# Install pip packages from config
log "Installing pip packages..."
pip_packages=$(yq -r '.python.pip_install[]?' "$config_file" 2>/dev/null)

if [[ -z "$pip_packages" ]]; then
  log "⚠️  No pip packages found in config"
else
  while IFS= read -r package; do
    if [[ -n "$package" && "$package" != "null" ]]; then
      log "Installing package: $package"
      pip install "$package"
    fi
  done <<< "$pip_packages"
  log "✅ Pip packages installed"
fi

log "======================================"
log "✅ Mamba Python tooling setup complete"
log "======================================"


log ""
log "=== ▶️ === "
log ""