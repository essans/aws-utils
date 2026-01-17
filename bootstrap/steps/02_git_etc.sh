#!/usr/bin/env bash

# Config git so it can be used on the remote instance as if it were local.
# Ensures git is installed and configures global git settings, appends some useful aliases to 
# .bashrc if not already present.  Then clones any repos specified in user config file

# To do:
# - Implement in a way that does not require config file to have name, email...
# - Remove yq check once confirmed handled in earlier step
# - Projects to clone --> change to readarray method then make config yaml consistent by adding "-"'s'
# - a lot of help from claude and codex for some of this.  need to review and build some intuition 
# around some of the patterns/techniques used!

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

log "=== STARTING GITHUB SETUP ==="


# Try to install yq early.  For now non-fatal if it fails
ensure_yq_installed || true


git_set_if_unset() {
  local key="$1" val="$2"

  # If the git config key is not set globally, set it to the provided value.
  if ! git config --global --get "$key" >/dev/null 2>&1; then
    git config --global "$key" "$val"
    log "git config --global $key $val"
  else
    log "git config $key already set (skipping)"
  fi
}

# via claude a function to append a block of text to a file only if a specific marker is not already present.
append_block_once() {
  # $1 is the file to append to, 
  # $2 is the marker string to check for, and the rest ($3...) is the content to append.
  local file="$1" marker="$2"
  shift 2
  local content="$*"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fq "$marker" "$file"; then
    log "Dotfiles block already present in $file (skipping)"
    return 0 
  fi

  # Append the block with markers to the file
  cat >>"$file" <<EOF


$marker
$content
# END BOOTSTRAP DOTFILES
EOF
  log "Appended dotfiles block to $file"
}


ensure_known_host() {
  local host="$1"
  # Pre-trust GitHub host key -avoid interactive prompt first git clone over SSH
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/known_hosts"
  chmod 600 "$HOME/.ssh/known_hosts"

  # Ensures that the SSH host key for github.com is in known_hosts file
  # This avoids interactive prompt the first time git is used via SSH.
  # sskeygen -tool to fetch public SSH host keys from a server
  if have ssh-keygen && ssh-keygen -F "$host" >/dev/null 2>&1; then
    log "$host already in known_hosts"
    return 0
  fi

  if have ssh-keyscan; then
    log "Adding $host to known_hosts..."
    ssh-keyscan -H "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
  else
    log "ssh-keyscan not found; skipping known_hosts warmup for $host"
  fi
}


# via claude, function to check if ssh-agent is available (ie was passed via ssh)
agent_available() {
  # SSH_AUTH_SOCK indicates a forwarded (or local) agent socket.
  # ssh-add -l returns 0 when identities are present.
  # on local machine, run: eval "$(ssh-agent -s)" and ssh-add ~/.ssh/id_ed25519
  [[ -n "${SSH_AUTH_SOCK:-}" ]] && have ssh-add && ssh-add -l >/dev/null 2>&1
}


# via claude a function to to test the git/hub ssh 
test_github_ssh() {
  # ssh -T returns exit code 1 on success for GitHub (it prints a greeting, then exits 1).
  # Treats "authenticated" as success if output indicates it.
  local out rc # capture output and return code
  out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  rc=$?
  # GitHub usually says: "Hi <user>! You've successfully authenticated..."
  if echo "$out" | grep -qi "successfully authenticated"; then
    log "GitHub SSH auth OK."
    return 0
  fi
  log "GitHub SSH auth NOT confirmed."
  log "ssh output (for debugging): $out"
  return 1
}


clone_or_pull_repo() {
  local repo_url="$1"
  local dest_dir="$2"

  mkdir -p "$(dirname "$dest_dir")"

  if [[ -d "$dest_dir/.git" ]]; then
    log "Repo already present. Pulling latest (rebase)..."
    git -C "$dest_dir" pull --rebase
  else
    log "Cloning: $repo_url -> $dest_dir"
    git clone "$repo_url" "$dest_dir"
  fi
}


log "=== Step 02: git set-up ==="

# Parse YAML for git user.name, user.email and other details
config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

if [[ -f "$config_file" ]]; then

  git_user_name=$(yq '.git.user.name' "$config_file")
  log "user_name: $git_user_name"

  git_user_email=$(yq '.git.user.email' "$config_file")
  log "user_email: $git_user_email"

  org_name=$(yq '.git.user.org' "$config_file")
  log "org_name: $org_name"

  local_dir_name=$(yq '.git.projects_dir' "$config_file")
  log "projects_dir: $local_dir_name"

  # Extract projects_repos_to_clone as a space-separated list
  projects_repos_to_clone=$(yq -r '.git.projects_repos_to_clone | split(" ") | join(" ")' "$config_file")
  log "projects_repos_to_clone: $projects_repos_to_clone"

  # Extract home_dir_repos_to_clone as a space-separated list
  home_dir_repos_to_clone=$(yq -r '.git.home_dir_repos_to_clone | split(" ") | join(" ")' "$config_file")
  log "home_dir_repos_to_clone: $home_dir_repos_to_clone"

else
  log "No config.yaml found at $config_file, skipping git user.name and user.email"
fi

ensure_apt
require_sudo

# Ensure git exists
if ! have git; then
  log "Installing git..."
  sudo -n apt-get update -y
  sudo -n apt-get install -y git
else
  log "git already installed"
fi

# Sensible git defaults suggested by claude
git_set_if_unset init.defaultBranch main
git_set_if_unset pull.rebase true
git_set_if_unset rebase.autoStash true
git_set_if_unset fetch.prune true
git_set_if_unset core.editor "code --wait"


# set user_name and user_email  
if [[ -n "$git_user_name" ]]; then
  git_set_if_unset user.name "$git_user_name"
fi
if [[ -n "$git_user_email" ]]; then
  git_set_if_unset user.email "$git_user_email"
fi


# create projects dir
if [[ ! -d "$HOME/$local_dir_name" ]]; then
  mkdir -p "$HOME/$local_dir_name"
  log "Created workspace dir: $HOME/$local_dir_name"
else
  log "Workspace dir already exists: $HOME/$local_dir_name (skipping)"
fi

# Add a small, marked bashrc block once (no duplication)
append_block_once "$HOME/.bashrc" "# BEGIN BOOTSTRAP DOTFILES" \
"export EDITOR='code --wait'
alias ll='ls -alF'
alias gs='git status'
alias gp='git pull --rebase'
alias gl='git log --oneline --decorate -n 20'
cdw(){ cd \"\$HOME/$local_dir_name\"; }"

ensure_known_host github.com

# -----------------------------------------------
# Clone requested repos with public/private check
# -----------------------------------------------

log "Checking GitHub SSH authentication..."
if ! test_github_ssh; then
  log "⚠️ WARNING: GitHub SSH authentication failed. Private repos will not be accessible."
fi

repos_to_clone=""
for repo in $projects_repos_to_clone; do
  repos_to_clone+="$local_dir_name/$repo "
done
for repo in $home_dir_repos_to_clone; do
  repos_to_clone+="$repo "
done

cloned_repos=()
failed_repos=()

# lots of help from claude and codex in getting this to work with the desired private/public flexibility
for repo_path in $repos_to_clone; do
  # Determine repo name and destination
  if [[ "$repo_path" == "$local_dir_name"/* ]]; then
    repo="${repo_path#$local_dir_name/}"
    dest="$HOME/$local_dir_name/$repo"
  else
    repo="$repo_path"
    dest="$HOME/$repo"
  fi
  ssh_url="git@github.com:$org_name/$repo.git"
  https_url="https://github.com/$org_name/$repo.git"

  # Skip if repo already exists
  if [[ -d "$dest/.git" ]]; then
    log "Repo $repo already exists at $dest (skipping)"
    cloned_repos+=("$repo")
    continue
  fi

  log "Checking if $repo is public..."
  # Prevent git from prompting for credentials
  if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true git ls-remote "$https_url" &>/dev/null; then
    log "Repo $repo is public. Attempting HTTPS clone..."
    if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true git clone "$https_url" "$dest" &>/dev/null; then
      log "Successfully cloned public repo: $repo to $dest"
      cloned_repos+=("$repo")
    else
      log "❌ FAILED to clone public repo: $repo to $dest"
      failed_repos+=("$repo (public, clone error)")
    fi
  else
    log "Repo $repo is private or inaccessible via HTTPS. Attempting SSH clone..."
    if test_github_ssh; then
      if git clone "$ssh_url" "$dest" &>/dev/null; then
        log "Successfully cloned private repo: $repo to $dest"
        cloned_repos+=("$repo")
      else
        log "❌ FAILED to clone private repo: $repo to $dest"
        failed_repos+=("$repo (private, clone error)")
      fi
    else
      log "Cannot clone private repo $repo: GitHub SSH authentication failed."
      failed_repos+=("$repo (private, no SSH auth)")
    fi
  fi
done

# Summary logging
log "==== Repo clone summary ===="
if [[ ${#cloned_repos[@]} -gt 0 ]]; then
  log "🟢 Successfully cloned: ${cloned_repos[*]}"
else
  log "🔴 No repos were successfully cloned."
fi
if [[ ${#failed_repos[@]} -gt 0 ]]; then
  log "🔴 Failed to clone: ${failed_repos[*]}"
fi


log "=========================="
log "✅ git etc set-up complete"
log "=========================="

log ""
log "=== ▶️ === "
log ""