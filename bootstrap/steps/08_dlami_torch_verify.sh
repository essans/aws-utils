#!/usr/bin/env bash

# For aws deep-learning AMIs a script to verify default torch set-up
# 
# Tested with venv only!

# To do:
#  - will this work with mamba ??

set -euo pipefail

log() { echo "[$(date -Is)]" "$@"; }
have() { command -v "$1" >/dev/null 2>&1; }


# If CREATE_VENV=1 then create/refresh a lightweight venv for project dependencies.
CREATE_VENV="${CREATE_VENV:-0}"
VENV_NAME="${VENV_NAME:-pytorch}" # DL-AMI default venv name
VENV_DIR="${VENV_DIR:-/opt}" # DL-AMI default is ~/opt
ENV_PATH="$VENV_DIR/$VENV_NAME"

EXTRA_PIP_PACKAGES="${EXTRA_PIP_PACKAGES:-}" # empty by default

log "=== STARTING DLAMI TORUCH/CUDA VERIFICATION ==="

log "--- System ---"
uname -a || true
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  log "OS: ${NAME:-unknown} ${VERSION:-unknown}"
fi

log "--- GPU / Driver ---"
if have nvidia-smi; then
  nvidia-smi || true
  log "GPU name(s):"
  nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || true
else
  log "WARNING: nvidia-smi not found. Either no NVIDIA driver, no GPU, or not a GPU DLAMI."
fi

log "--- CUDA tooling ---"
if have nvcc; then
  nvcc --version || true
else
  log "NOTE: nvcc not found (CUDA toolkit may not be installed, which is OK on many DLAMIs)."
fi

log "--- Python ---"
if have python3; then
  python3 -V || true
else
  log "❌ ERROR: python3 not found."
  exit 2
fi

log "--- Activating DLAMI PyTorch environment ---"
DLAMI_PYTORCH_ENV="/opt/pytorch/bin/activate" # hard-code DLAMI default
if [[ -f "$DLAMI_PYTORCH_ENV" ]]; then
  log "Sourcing DLAMI PyTorch environment: $DLAMI_PYTORCH_ENV"
  source "$DLAMI_PYTORCH_ENV"
else
  log "WARNING: DLAMI PyTorch environment not found at $DLAMI_PYTORCH_ENV"
  log "Continuing with system Python..."
fi

log "--- PyTorch check (system python) ---"
torch_verify_output=$(
python3 - <<'PY'
import sys
print("python:", sys.version.split()[0])
try:
    import torch
    print("torch:", torch.__version__)
    print("torch.cuda.is_available():", torch.cuda.is_available())
    print("torch.version.cuda:", torch.version.cuda)
    if torch.cuda.is_available():
        print("device_count:", torch.cuda.device_count())
        print("device_0:", torch.cuda.get_device_name(0))
except Exception as e:
    print("ERROR importing/using torch:", repr(e))
    raise
PY
)
while IFS= read -r line; do
  log "$line"
done <<< "$torch_verify_output"


if [[ "$CREATE_VENV" == "1" ]]; then
  log "--- Creating/using venv ---"
  mkdir -p "$VENV_DIR"

  if [[ ! -d "$ENV_PATH" ]]; then
    log "Creating venv at: $ENV_PATH"
    python3 -m venv "$ENV_PATH"
  else
    log "Venv already exists: $ENV_PATH"
  fi

  source "$ENV_PATH/bin/activate"

  log "Upgrading pip tooling in venv..."
  pip install --upgrade pip setuptools wheel >/dev/null

  if [[ -n "$EXTRA_PIP_PACKAGES" ]]; then
    log "Installing extra packages into venv: $EXTRA_PIP_PACKAGES"
    pip install $EXTRA_PIP_PACKAGES
  else
    log "No extra packages requested for venv."
  fi

  log "--- PyTorch check (venv python) ---"
  python - <<'PY'
import sys
print("python (venv):", sys.version.split()[0])
try:
    import torch
    print("torch (venv):", torch.__version__)
    print("torch.cuda.is_available() (venv):", torch.cuda.is_available())
    print("torch.version.cuda (venv):", torch.version.cuda)
    if torch.cuda.is_available():
        print("device_0 (venv):", torch.cuda.get_device_name(0))
except Exception as e:
    print("ERROR importing/using torch in venv:", repr(e))
    raise
PY

  log "Venv ready. Activate with: source \"$ENV_PATH/bin/activate\""
fi

log "============================"
log "✅ aws dlami-check completed"
log "============================"

log ""
log "=== ▶️ === "
log ""