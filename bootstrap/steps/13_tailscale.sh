#!/usr/bin/env bash

# Script to install and setup Tailscale in remote instance.
# Tailscale authentication typically requires an interactive login step unless
# an auth key is provided through TS_AUTHKEY.

# To do:
#  - Automate transfer-in of non-project-specific tailscale settings
#  - Integrate TS_AUTHKEY retrieval from AWS Secrets Manager
#  - Add optional tags/advertise-routes defaults per environment

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

log "=== STARTING TAILSCALE SETUP ==="

# (1) Check Ubuntu version (validated on 24.04)
log "Checking Ubuntu version..."
if [ -f /etc/os-release ]; then
  source /etc/os-release
  if [[ "$VERSION_ID" != "24.04" ]]; then
    log "❌ ERROR: Ubuntu 24.04 is required for this Tailscale setup step (found: $VERSION_ID)"
    exit 1
  fi
  log "✅ Ubuntu version check passed: $VERSION_ID"
else
  log "❌ ERROR: Cannot determine Ubuntu version (/etc/os-release not found)"
  exit 1
fi

# (2) Install tailscale package (official install script)
log "🔄 Installing Tailscale..."
require_sudo

if ! have tailscale; then
  log "Tailscale not found, installing from official script..."
  curl -fsSL https://tailscale.com/install.sh | sh
else
  log "Tailscale already installed"
fi

# (3) Ensure tailscaled service is enabled/running
log "Ensuring tailscaled service is enabled and running..."
sudo systemctl enable --now tailscaled

if sudo systemctl is-active --quiet tailscaled; then
  log "✅ tailscaled service is active"
else
  log "❌ ERROR: tailscaled service is not active"
  exit 1
fi

# (4) Bring up Tailscale; prefer auth key if provided to avoid interactive login
# if [ -n "${TS_AUTHKEY:-}" ]; then
#   log "Using TS_AUTHKEY to run non-interactive tailscale up..."
#   sudo tailscale up --authkey "${TS_AUTHKEY}"
# else
#   log "No TS_AUTHKEY detected; starting interactive tailscale up flow..."
#   sudo tailscale up
# fi

# (5) Validate connection state
# log "Checking Tailscale status..."
# if tailscale status >/dev/null 2>&1; then
#   TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || true)
#   if [ -n "$TAILSCALE_IP" ]; then
#     log "✅ Tailscale connected. IPv4: $TAILSCALE_IP"
#   else
#     log "✅ Tailscale command works; no IPv4 reported yet"
#   fi
# else
#   log "❌ ERROR: tailscale status failed"
#   exit 1
# fi

log "========================================="
log "✅ tailscale installed and ready to use"
log "--> sudo tailscale up"
log "========================================="

log ""
log "=== ▶️ ==="
log ""
