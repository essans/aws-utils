#!/usr/bin/env bash

# Once a remote instance is set-up not all work is via the command line.  If an IDE is needed
# the easiest way is to connect via vs-code's REMOTE-SSH connect feature from a local machine:
# 1. Open VS Code locally and install the 'Remote - SSH' extension.
# 2. Press F1, select 'Remote-SSH: Connect to Host...', and enter: ubuntu@<ec2-ip>
# 3. Use SSH key when prompted. Or save all details in in .ssh/config for convenience:
# 
# Host node
#     HostName 3.94.127.237
#     IdentityFile ~/.ssh/default_ed25519
#     User ubuntu
#     ForwardAgent yes
#
# This script provides options to (1) have a jupyter server running on remote instance and connect
# locally via a web-browser.  (2) create a tunnel through which can connect via vs-code on the web.

# For how to use see script output at bottom of this file

# To do:
#  - as per earlier some earlier steps allow environment dir to be a user-config. 
#  - got lazy and included some hardcoded reliance on "09_ide_setup.sh", so don't change!
#  - need to understand how stable the hardcoded url is for the vs-code curl
#  - currently defaults to use of venv.  Update to set-up in mamba too (or optionally)

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    log "❌ ERROR: sudo would prompt for password (non-interactive required)."
    exit 1
  fi
}

log "=== STARTING JUPYTER SERVER/NOTEBOOK SETUP  === "

config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

echo "debug: using $config_file..."

# Check if mamba is installed (command or directory)
USE_MAMBA=false
if command -v mamba >/dev/null 2>&1 || command -v micromamba >/dev/null 2>&1 || [[ -f "$HOME/miniforge3/bin/mamba" ]]; then
  USE_MAMBA=true
  log "Mamba detected - will use mamba environment"
else
  log "Mamba not detected - will use venv"
fi

if [[ "$USE_MAMBA" == "true" ]]; then
  # Mamba path: use mamba environment
  if ! command -v mamba >/dev/null 2>&1; then
    log "Sourcing miniforge3 initialization..."
    if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
      source "$HOME/miniforge3/etc/profile.d/conda.sh"
    fi
  fi
  
  # Get mamba environment name from config
  if have yq; then
    MAMBA_ENV=$(yq -r '.python.mamba_env // "default"' "$config_file" 2>/dev/null || echo "default")
  else
    MAMBA_ENV="default"
  fi
  
  log "Using mamba environment: $MAMBA_ENV"
  
  # Activate mamba environment
  conda activate "$MAMBA_ENV"
  
  # Install Jupyter and ipykernel via pip in the mamba environment
  log "Installing Jupyter and ipykernel in mamba environment: $MAMBA_ENV"
  pip install --upgrade pip
  pip install jupyter ipykernel
  
  log "Jupyter and ipykernel installed in mamba environment: $MAMBA_ENV"
  
else
  # Venv path: use venv environment
  if ! have python3; then
    log "python3 not found, installing..."
    require_sudo
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv
  else
    log "python3 already installed"
  fi
  
  # Extract venv name from config if available
  VENV_NAME="venv"
  if [ -n "$config_file" ] && [ -f "$CONFIG_FILE" ]; then
    if have yq; then
      VENV_NAME=$(yq -r '.python.venv // "venv"' "$config_file" 2>/dev/null || echo "venv")
      log "Venv name from config: $VENV_NAME"
    fi
  fi
  
  echo "debug: using $VENV_NAME as the env"
  
  VENV_DIR="$HOME/environments"
  if [ -n "$config_file" ] && [ -f "$config_file" ] && have yq; then
      env_subdir=$(yq -r '.python.env_dir_in_home // "environments"' "$config_file" 2>/dev/null || echo "environments")
      VENV_DIR="$HOME/$env_subdir"
  fi
  TARGET_VENV="$VENV_DIR/$VENV_NAME"
  
  log "Installing Jupyter and ipykernel in venv: $TARGET_VENV"
  
  mkdir -p "$VENV_DIR"
  
  if [ ! -d "$TARGET_VENV" ]; then
    log "Creating venv at $TARGET_VENV..."
    python3 -m venv "$TARGET_VENV"
  else
    log "Venv already exists at $TARGET_VENV"
  fi
  
  # Install Jupyter and ipykernel in the target venv
  "$TARGET_VENV/bin/pip" install --upgrade pip
  "$TARGET_VENV/bin/pip" install jupyter ipykernel
  
  log "Jupyter and ipykernel installed in $TARGET_VENV"
  
  # Activate venv for this session
  source "$TARGET_VENV/bin/activate"
  log "Activated venv: $VIRTUAL_ENV"
fi
CONFIG_DIR="$HOME/.jupyter"
CONFIG_FILE="$CONFIG_DIR/jupyter_notebook_config.py"

mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  log "Generating Jupyter config..."
  jupyter notebook --generate-config
else
  log "Jupyter config already exists"
fi

# Suggested but claude: ensure desired settings are present without duplicating on reruns
if ! grep -q "Added by bootstrap/steps/09_ide_setup.sh" "$CONFIG_FILE"; then
  cat <<'EOF' >> "$CONFIG_FILE"

# Added by bootstrap/steps/09_ide_setup.sh
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.open_browser = False
c.NotebookApp.port = 8888
# To require a password/token, set c.NotebookApp.token or c.NotebookApp.password
EOF
  log "Updated $CONFIG_FILE with notebook settings"
else
  log "Notebook settings already present in $CONFIG_FILE"
fi

log "=================================="
log "✅ Jupyter Notebook setup complete"
log "=================================="


log "=== STARTING VS CODE SERVER SETUP ==="

VSCODE_CLI_DIR="$HOME/.vscode-cli"
mkdir -p "$VSCODE_CLI_DIR"

BASHRC_FILE="$HOME/.bashrc"

if [ ! -f "$VSCODE_CLI_DIR/code" ]; then
  log "Downloading VS Code CLI for Linux..."
  # Use the direct update URL for VS Code CLI
  if curl -fsSL 'https://update.code.visualstudio.com/latest/cli-linux-x64/stable' -o "$VSCODE_CLI_DIR/vscode-cli.tar.gz"; then
    tar -xzf "$VSCODE_CLI_DIR/vscode-cli.tar.gz" -C "$VSCODE_CLI_DIR"
    rm "$VSCODE_CLI_DIR/vscode-cli.tar.gz"
    log "VS Code CLI installed at $VSCODE_CLI_DIR"
  else
    log "❌ ERROR: Failed to download VS Code CLI"
    exit 1
  fi
else
  log "VS Code CLI already installed"
fi

if ! grep -q '\.vscode-cli' "$BASHRC_FILE"; then
  echo "" >> "$BASHRC_FILE"
  echo "# VS Code CLI (added by IDE setup)" >> "$BASHRC_FILE"
  echo 'export PATH="$PATH:$HOME/.vscode-cli"' >> "$BASHRC_FILE"
  log "Added VS Code CLI to PATH in ~/.bashrc"
else
  log "VS Code CLI already in PATH"
fi

export PATH="$PATH:$VSCODE_CLI_DIR"

log "================================"
log "✅ VS Code Server setup complete"
log "================================"


log ""

log "To start VS Code Server, run:"
log "  code tunnel --accept-server-license-terms"
log ""
log "Then authenticate with GitHub when prompted and access via:"
log "  https://vscode.dev/tunnel/<machine-name>"
log "=================================================================================="
log ""
log "Jupyter Notebook usage:"
log "- Use your preferred venv, then run: source <venv>/bin/activate"
log "- Create a new tmux session and cd into the project's directory, install requirements etc"
log "-- Start the server with: jupyter notebook --no-browser --port=8888 --ip=0.0.0.0"
log "-- Note the token in the link that is shown (unless using a password)"
log "- Method-1:"
log "-- In local browser: http://<ec2-ip:8888/lab and enter token when prompted"
log "- Method-2:"
log "-- In a new terminal window on LOCAL machine create SSH tunnel:"
log "-- ssh -N -L 8888:localhost:8888 -i <path/to/github_cred> ubuntu@<ec2-ip>"
log "-- In a web browser: http://localhost:8888/lab"
log "=================================================================================="

log ""
log "=== ▶️ === "
log ""