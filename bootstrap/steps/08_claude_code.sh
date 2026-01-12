#!/usr/bin/env bash

# Script to setup claude-code scaffold in remote instance. Requires interactive authentication 
# on  on first use on the instance.

# This might work to set explicitly:
# 1. Get your API key from: https://console.anthropic.com/settings/keys
# 2. Add to ~/.bashrc: echo 'export ANTHROPIC_API_KEY=\"your-key-here\"' >> ~/.bashrc
# 3. Or set temporarily: export ANTHROPIC_API_KEY=\"your-key-here\"
# 4. After setting the key, run: source ~/.bashrc

# To do:
#  - Automate the transfer-in of non-project-specific claude-code settings, configs
#  - Transfer-in credentials (via aws secrets?) to avoid the need for interactive authentication
#  - How to avoid the need to 'source ~/.bashrc' upon completion

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; }
have() { command -v "$1" >/dev/null 2>&1; }

require_sudo() {
  # non-interactive sudo check (prevents the script from hanging on a password prompt)
  if ! sudo -n true 2>/dev/null; then
    log "❌ ERROR: sudo would prompt for password."
    exit 1
  fi
}

log "=== STARTING CLAUDE-CODE SETUP ==="

# (1) Check that Ubuntu 24.04 is being used (only version I've checked tbh)
log "Checking Ubuntu version..."
if [ -f /etc/os-release ]; then
  source /etc/os-release
  if [[ "$VERSION_ID" != "24.04" ]]; then
    log "❌ ERROR: Ubuntu 24.04 is required for Claude Code setup (found: $VERSION_ID)"
    log "Node.js 18+ may not be available in the package repository for this version."
    exit 1
  fi
  log "✅ Ubuntu version check passed: $VERSION_ID"
else
  log "❌ ERROR: Cannot determine Ubuntu version (/etc/os-release not found)"
  exit 1
fi

# (2) Install Node.js and npm (version 10 or higher)
log "🔄 Installing Node.js and npm..."
require_sudo

if ! have node; then
  log "Node.js not found, installing..."
  sudo apt-get update -qq
  sudo apt-get install -y nodejs npm
else
  log "Node.js already installed"
fi

# (3) Set up npm to install global packages in home directory
log "Configuring npm for global packages in home directory..."
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global

# (4) Update PATH in ~/.bashrc
log "Updating PATH in ~/.bashrc..."
if ! grep -q '\.npm-global/bin' ~/.bashrc; then
  echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
  log "Added npm global bin to PATH in ~/.bashrc"
else
  log "npm global bin already in ~/.bashrc"
fi

# Source the updated bashrc to update current session
export PATH=~/.npm-global/bin:$PATH
log "Current PATH: $PATH"

# Upgrade npm to version 10
log "Upgrading npm to version 10..."
npm install -g npm@10

# Source the updated bashrc to update current session
export PATH=~/.npm-global/bin:$PATH
log "Current PATH: $PATH"

# Verify Node.js version
NODE_VERSION=$(node --version | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
log "Node.js version: $NODE_VERSION"

if [ "$NODE_MAJOR" -lt 18 ]; then
  log "❌ ERROR: Node.js version 18 or higher is required (found: $NODE_VERSION)"
  exit 1
fi

# Verify npm version
NPM_VERSION=$(npm --version)
NPM_MAJOR=$(echo "$NPM_VERSION" | cut -d. -f1)
log "npm version: $NPM_VERSION"

if [ "$NPM_MAJOR" -lt 10 ]; then
  log "❌ ERROR: npm version 10 or higher is required (found: $NPM_VERSION)"
  exit 1
fi

# Install Claude Code
log "🔄 Installing Claude Code globally..."
npm install -g @anthropic-ai/claude-code

# Test the installation
log "Testing Claude Code installation..."
if command -v claude >/dev/null 2>&1; then
  CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "version check failed")
  log "✅ Claude Code installed successfully! Version: $CLAUDE_VERSION"
else
  log "❌ ERROR: Claude Code installation failed - 'claude' command not found"
  exit 1
fi


log "run claude command to complete set-up"


log "========================================="
log "✅ claude-code installed and ready to use"
log "========================================="

