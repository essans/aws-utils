#!/usr/bin/env bash

# Misc environment set-ups on the remote instance

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

log "=== STARTING OTHER BASIC SETUPS ==="


# Potentially re-using this function claude suggested for use in an earlier step
append_block_once() {
  local file="$1" marker="$2"
  shift 2
  local content="$*"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fq "$marker" "$file"; then
    log "Dotfiles block already present in $file (skipping)"
    return 0 
  fi

  cat >>"$file" <<EOF


$marker
$content
# END BOOTSTRAP DOTFILES
EOF
  log "Appended dotfiles block to $file"
}


config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

# Parse dirs list from config file, create each directory
readarray -t dirs_to_create < <(yq eval '.dirs[]' "$config_file" 2>/dev/null || true)

for dir in "${dirs_to_create[@]}"; do
  [[ -z "$dir" ]] && continue
  mkdir -p "$HOME/$dir"
  log "Created directory: $HOME/$dir"
done

log "============================="
log "✅ local directories created."
log "============================="
