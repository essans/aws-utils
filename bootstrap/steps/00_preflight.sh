#!/usr/bin/env bash

# Perform "preflight" checks before kicking-off bootstrap process.
# OS type, architecture, shell availability, disk space, network connectivity,
# DNS resolution, sudo permissions, system time, and write permissions.

# To do: implement some of the checks from subsequent steps into pre-flight checks
# and allow some of those dependencies to be resolved here.

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; } 

# helper function to verify if a command exists., and redirect/silence stdout and stderr
have() { command -v "$1" >/dev/null 2>&1; }


# function to log fatal errors and exit with non-zero status
fail() {
  log "❌ FATAL: $*"
  exit 1
}

log "=== STARTING PREFLIGHT CHECKS ==="

# ---------- OS ----------
log "🔍 Checking OS..."
uname -a || fail "uname failed"

# Using -f test operator to check for /etc/os-release
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  log "OS: ${NAME:-unknown} ${VERSION:-unknown}"
else
  log "⚠️ WARNING: /etc/os-release not found"
fi

# ---------- architecture ----------
arch="$(uname -m)"
log "Architecture: $arch"

# case statement to check for known architectures
case "$arch" in
  x86_64|aarch64|arm64) ;;
  *)
    log "⚠️ WARNING: untested architecture: $arch"
    ;;
esac

# ---------- shell ----------
log "Shell: $SHELL"
bash --version | head -n 1 || fail "bash not available"

# ---------- disk space ----------
log "🔍 Checking disk space..."
df -h / | awk 'NR==1 || NR==2 {print}' #awk first and second lines only
avail_kb="$(df --output=avail / | tail -n1)" #tail last line
log "Available space: $avail_kb"

if [[ "$avail_kb" -lt $((5 * 1024 * 1024)) ]]; then
  fail "Less than 5GB free disk space on /"
fi

# ---------- network ----------
log "🔍 Checking network connectivity..."
if have ping; then
  ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 || fail "No network connectivity (ping failed)"
else
  have curl || fail "Neither ping nor curl available for network check"
  curl -fsSL https://example.com >/dev/null || fail "Network connectivity failed (curl)"
log "  Network available"
fi

# ---------- DNS ----------
log "🔍 Checking DNS..."
# "get entries" from system databases
getent hosts github.com >/dev/null 2>&1 || fail "DNS resolution failed (github.com)"
log "  Succeeded"

# ---------- sudo ----------
log "🔍 Checking sudo (non-interactive)..."
if ! sudo -n true 2>/dev/null; then
  fail "sudo would prompt for password (non-interactive required)"
log "  Non-interactive mode confirmed"
fi

# ---------- time ----------
log "🔍 Checking system time..."
date -Is || fail "date failed"
log "  ok"

# ---------- permissions ----------
log "🔍 Checking write permissions..."
touch "$HOME/.bootstrap_write_test" || fail "Cannot write to \$HOME"
rm -f "$HOME/.bootstrap_write_test"
log "  Able to write"

# ---------- memory ----------
log "🔍 Checking memory..."
mem_total_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)" # awk 2nd field when matched
mem_total_gb=$((mem_total_kb / 1024 / 1024))
log "Total memory: ${mem_total_gb} GB"

if [[ "$mem_total_kb" -lt $((1 * 1024 * 1024)) ]]; then
  fail "Less than 1GB RAM detected"
fi

# ---------- CPU ----------
log "🔍 Checking CPU..."
cpu_model="$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)"
cpu_cores="$(nproc)"
log "CPU model: $cpu_model"
log "CPU cores: $cpu_cores"

if [[ "$cpu_cores" -lt 1 ]]; then
  fail "No CPU cores detected"
fi

# ---------- open ports ----------
# ss -tuln displays all TCP and UDP sockets that are currently listening
log "🔍 Checking open (listening) ports..."
if have ss; then
  log "Open ports (ss):"
  ss -tuln | awk 'NR==1 || /LISTEN/' | while read -r line; do log "$line"; done
elif have netstat; then
  log "Open ports (netstat):"
  netstat -tuln | awk 'NR==1 || /LISTEN/' | while read -r line; do log "$line"; done
else
  log "⚠️ WARNING: Neither ss nor netstat available to check open ports."
fi

log "============================"
log "✅ Preflight checks PASSED."
log "============================"

log ""
log "=== ▶️ === "
log ""


