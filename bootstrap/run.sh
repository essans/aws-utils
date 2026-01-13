#!/usr/bin/env bash

# The main script which calls and runs a series of modular "bootstrap" steps for post-launch 
# configuration of an EC2 instance.  Each step is a separate shell script located in the 'steps' 
# directory. See the comments at the top of each file for details.  

# Usage:
# run.sh [options]
#
#Options:
#  --config <file>     Path to config.yaml (default: $HOME/bootstrap/config.yaml)
#  --skip 01,05,08     Skip steps by numeric prefix (comma/space-separated)
#  --only 00,02        Run only these step numbers (comma/space-separated)
#  --dry-run           Show what would run; do not execute or write stamps (default)
#  --run               Actually execute steps (disables dry-run)
#  --force             Run steps even if already stamped as done
#  --help              Show help
#
#Notes:
#1. By default, the script runs in dry-run mode for safety. Use --run to execute steps.
#2. Step files must be named like NN_name.sh (e.g., 00_preflight.sh).
#3. steps can be specified of xx_'d out in the config file
#4. --only takes precedence by skipping everything not listed.
#
# eg:
# cd ~/bootstrap
# bash run.sh --config <config_ filename.yaml> --run
# bash run.sh --config <config_ filename.yaml> --skip 06,07 --run
# bash run.sh --config <config_ filename.yaml> --only 08 --run --force

# Good to knows: 
# After completion if something is not working try source ~/.bashrc  

# To do:
#   - figure out why source ~/.bashrc is inconsistent in how to persists across sessions


set -euo pipefail

# ----- paths -----
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEPS_DIR="$BOOTSTRAP_DIR/steps"

# ----- configs -----
STATE_DIR="${STATE_DIR:-$HOME/.bootstrap_state}"
LOG_FILE="${LOG_FILE:-$HOME/bootstrap/bootstrap.log}"
# Config file path (default; usually a good idea to override via --config argument)
CONFIG_FILE="$HOME/bootstrap/config.yaml"

DRY_RUN=1 #default
FORCE=0
SKIP_STEPS="${SKIP_STEPS:-}"   # numbers: "01 05"
ONLY_STEPS="${ONLY_STEPS:-}"   # numbers: "00 02"

mkdir -p "$STATE_DIR" # used for checks when re-running

usage() {
  cat <<'EOF'
Usage: run.sh [options]

Options:
  --config <file>     Path to config.yaml (default: $HOME/bootstrap/config.yaml)
  --skip 01,05,08     Skip steps by numeric prefix (comma/space-separated)
  --only 00,02        Run only these step numbers (comma/space-separated)
  --dry-run           Show what would run; do not execute or write stamps (default)
  --run               Actually execute steps (disables dry-run)
  --force             Run steps even if already stamped as done
  --help              Show help

Notes:
  - By default, the script runs in dry-run mode for safety. Use --run to execute steps.
  - Step files must be named like NN_name.sh (e.g., 00_preflight.sh).
  - --only takes precedence by skipping everything not listed.
EOF
}

# Normalize a list of numbers: commas to spaces, squeeze whitespace, trim
normalize_nums() {
  # commas -> spaces, squeeze whitespace, trim
  echo "$1" | tr ',' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//'
}

num_in_list() {
  # $1=num (e.g. "05"), $2=list
  local n="$1"
  local list
  list="$(normalize_nums "$2")"
  [[ -z "$list" ]] && return 1
  for x in $list; do
    [[ "$x" == "$n" ]] && return 0
  done
  return 1
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || { echo "❌ ERROR: --config requires a value"; usage; exit 2; }
      CONFIG_FILE="$2"; shift 2 ;;
    --skip)
      [[ $# -ge 2 ]] || { echo "❌ ERROR: --skip requires a value"; usage; exit 2; }
      SKIP_STEPS="$2"; shift 2 ;;
    --only)
      [[ $# -ge 2 ]] || { echo "❌ ERROR: --only requires a value"; usage; exit 2; }
      ONLY_STEPS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --run) DRY_RUN=0; shift ;;
    --force)   FORCE=1; shift ;;
    --help)    usage; exit 0 ;;
    *) echo "❌ ERROR: Unknown arg: $1"; usage; exit 2 ;;
  esac
done

# Export CONFIG_FILE after argument parsing so other steps can use
export CONFIG_FILE

# ----- logging -----
# Redirect all output (stdout and stderr) to the log file, while also printing to console.
# 'tee -a "$LOG_FILE"' takes everything printed and appends it to the log file, while also displaying it live.
# 'exec > ...' replaces the script’s output stream, so every command after this line is affected.  It's a way to permanently change where the script’s output goes, starting from that line.
exec > >(tee -a "$LOG_FILE") 2>&1


log() { echo "[$(date -Is)]" "$@"; }

# ----- state helpers -----
# Function to mark a step as completed
# step_ok: creates a file indicating the step is done
# step_done: checks if the step has been completed
step_done() { [[ -f "$STATE_DIR/$1.ok" ]]; }
mark_done() { touch "$STATE_DIR/$1.ok"; }

# Run a step if not already done
run_step() {
  local step_file="$1"
  
  local step_name step_num  # added step_num
  step_name="$(basename "$step_file" .sh)" 

  step_num="${step_name%%_*}" # remove everything after the first underscore.


  # Validate prefix looks like NN using regex
  if [[ ! "$step_num" =~ ^[0-9][0-9]$ ]]; then
    log "SKIP $step_name (invalid step prefix; expected NN_)"
    return 0
  fi

  # Skip/only controls by number
  if num_in_list "$step_num" "$SKIP_STEPS"; then
    log "SKIP $step_name (step $step_num in --skip)"
    return 0
  fi

  if [[ -n "$(normalize_nums "$ONLY_STEPS")" ]] && ! num_in_list "$step_num" "$ONLY_STEPS"; then
    log "SKIP $step_name (step $step_num not in --only)"
    return 0
  fi


  # Stamp check
  # If FORCE is not set and step is done, skip it
  if [[ $FORCE -eq 0 ]] && step_done "$step_name"; then
    log "SKIP $step_name (already done)"
    return 0
  fi

  # Dry-run
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY  $step_name -> would run: bash \"$step_file\""
    return 0
  fi

  # From prior version
  #if step_done "$step_name"; then
  #  log "SKIP $step_name (already done)"
  #  return 0 # return success 0 to indicate step is done
  #fi

  log "RUN  $step_name" # run the step command
  bash "$step_file" # execute the step script file

  # added here:
  # After each step, re-source bashrc so any PATH/profile changes take effect
  if [[ -f "$HOME/.bashrc" ]]; then
    set +u
    # shellcheck disable=SC1090
    # Avoid failing the bootstrap if bashrc has interactive-only bits
    source "$HOME/.bashrc" || true
    set -u
    log "SOURCED ~/.bashrc to refresh environment for subsequent steps"
  fi
  
  mark_done "$step_name" # mark the step as completed
  log "DONE $step_name"
}

mode="EXECUTE"
[[ $DRY_RUN -eq 1 ]] && mode="DRY-RUN" # changes mode to DRY-RUN if DRY_RUN is set
[[ $FORCE  -eq 1 ]] && mode="$mode +FORCE" # appends +FORCE to mode if FORCE is set

# ----- main loop -----

START_TIME=$(date +%s)
START_TIME_HUMAN=$(date -Is)

log "=== 🔄 BOOTSTRAP START ==="
log "Bootstrap : $BOOTSTRAP_DIR"
log "Steps dir : $STEPS_DIR"
log "State dir : $STATE_DIR"
log "Log file  : $LOG_FILE"
log "Config    : $CONFIG_FILE"
log "Mode      : $mode"
log "Skip nums : ${SKIP_STEPS:-<none>}"
log "Only nums : ${ONLY_STEPS:-<none>}"


#log "=== BOOTSTRAP START ==="
#log "Steps dir : $STEPS_DIR"
#log "State dir : $STATE_DIR"
#log "Log file  : $LOG_FILE"

# new concept here... changes how Bash handles filename patterns (globs) that don’t match any files.  
# By default, if you write something like steps=( "$STEPS_DIR"/.sh ), and there are no .sh files in that folder, 
# Bash will put the literal string "$STEPS_DIR"/.sh into the array which can cause bugs, because you might think 
# you have a list of files, but you actually have a pattern that didn’t match anything... duh..
# With shopt -s nullglob, if no files match the pattern, the result is an empty array instead of a useless string. 
# This makes script safer and prevents accidental errors when looping over files that don’t exist.
# In other words 'shopt -s nullglob' makes sure that if a file pattern matches nothing, you get nothing 
# (not a broken pattern string). 
# This is especially important when you want to loop over files and need to be sure you’re not processing a non-existent file.
shopt -s nullglob

# Use awk to parse YAML list.  at this stage not sure if yq is available
log "Reading bootstrap steps from config..."
mapfile -t steps < <(awk '/^bootstraps:/ {flag=1; next} flag && /^  [^ ]/ {$1=$1; print; next} flag && /^[^ ]/ {flag=0}' "$CONFIG_FILE")

filtered_steps=()

for step_file in "${steps[@]}"; do
  # Skip commented out entries (lines starting with xx_)
  if [[ "$step_file" =~ ^xx_ ]]; then
    log "SKIP ${step_file#\#} (commented out with xx_ pattern in config)"
    continue
  fi
  
  step_name="${step_file%.sh}"  # Remove .sh extension
  step_num="${step_name%%_*}"   # Extract numeric prefix
  
  # Validate prefix looks like NN
  if [[ ! "$step_num" =~ ^[0-9][0-9]$ ]]; then
    log "SKIP $step_name (invalid step prefix; expected NN_)"
    continue
  fi
  
  # Apply skip/only filters
  if num_in_list "$step_num" "$SKIP_STEPS"; then
    log "SKIP $step_name (step $step_num in --skip)"
    continue
  fi
  
  if [[ -n "$(normalize_nums "$ONLY_STEPS")" ]] && ! num_in_list "$step_num" "$ONLY_STEPS"; then
    log "SKIP $step_name (step $step_num not in --only)"
    continue
  fi
  
  # Add full path to filtered steps
  filtered_steps+=("$STEPS_DIR/$step_file")
done

# Check if there are any steps after filtering
if [[ ${#filtered_steps[@]} -eq 0 ]]; then
  log "❌ ERROR: no bootstrap steps found in config (expected .bootstraps section in $CONFIG_FILE)"
  exit 1
fi

steps=("${filtered_steps[@]}")
shopt -u nullglob # reset to default behavior.  see above note

for step in "${steps[@]}"; do
  run_step "$step"
done

# Calculate duration
END_TIME=$(date +%s)
END_TIME_HUMAN=$(date -Is)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log "=== ✅ BOOTSTRAP COMPLETE ==="
log "Start time : $START_TIME_HUMAN"
log "End time   : $END_TIME_HUMAN"
log "Duration   : ${MINUTES}m ${SECONDS}s"
log "============================="
log ""
log "👉 run source ~/.bashrc"
log "👉 run source ~/environments/venv/bin/activate"
log "or create a new one:"
log "👉 python3 -m venv ~environments/env_name"
