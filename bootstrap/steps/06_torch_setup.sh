#!/usr/bin/env bash

# This script:
# - detects whether an NVIDIA GPU + driver is present (nvidia-smi)
# - chooses a PyTorch wheel variant (cpu, cu123 etc) based on the driver-reported CUDA version 
# - creates a dedicated
# - installs torch
# - runs a quick verification

# By design this does not try to install NVIDIA drivers or the CUDA toolkit as on EC2 this is 
# usually handled via choice of an appropriate DL AMI.  With this v1 wanted to keep things lightweight
# and avoid the usual driver/toolkit mismatch rabbit holes...

# See: https://pytorch.org/get-started/locally/

# Verify PyTorch sees GPU:
# --> python -c "import torch; print(torch.cuda.is_available(), torch.version.cuda)"

# To do:
#  - known issue from prior steps.  allow venv directory to be a user-config rather than ~/evironments

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

ensure_apt_pkg() {
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1 || sudo -n apt-get install -y "$pkg"
}

log "=== STARTING TORCH SETUPS ==="

config_file="${CONFIG_FILE:?ERROR: CONFIG_FILE environment variable not available}"

# Read venv name from config, otherwise use torch
if [[ -f "$config_file" ]]; then
  if have yq; then
    TORCH_ENV_NAME=$(yq -r '.python.venv // "torch"' "$config_file" 2>/dev/null || echo "torch")
  else
    log "yq not installed; using default venv name 'torch'"
    TORCH_ENV_NAME="torch"
  fi
else
  log "Config file not found; using default venv name 'torch'"
  TORCH_ENV_NAME="torch"
fi

TORCH_ENV_NAME="${TORCH_ENV_NAME:-torch}"
TORCH_PYTHON="${TORCH_PYTHON:-python3}"
TORCH_VARIANT="${TORCH_VARIANT:-auto}"   # auto|cpu|cu118|cu121|cu124|cu130
TORCH_VERSION="${TORCH_VERSION:-}"       # e.g. 2.5.1 (optional)
EXTRA_PIP_PACKAGES="${EXTRA_PIP_PACKAGES:-}"  # e.g. "numpy pandas transformers"

VENV_DIR="${VENV_DIR:-$HOME/environments}"
ENV_PATH="$VENV_DIR/$TORCH_ENV_NAME"


detect_cuda_variant_auto() {
  # Heuristic based on NVIDIA driver-reported "CUDA Version" in nvidia-smi output.
  # try to select appropriate PyTorch wheel for the detected CUDA version.
  # - If no GPU/driver, use cpu
  # - If CUDA >= 13.0 -> cu130
  # - Else if CUDA >= 12.4 -> cu124
  # - Else if CUDA >= 12.1 -> cu121
  # - Else if CUDA >= 11.8 -> cu118
  # - Else -> cpu
  if ! have nvidia-smi; then
    echo "cpu"
    return 0
  fi

  local smi
  smi="$(nvidia-smi 2>/dev/null || true)"
  if [[ -z "$smi" ]]; then
    echo "cpu"
    return 0
  fi

  local cuda_ver
  cuda_ver="$(echo "$smi" | sed -n 's/.*CUDA Version: \([0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)"
  if [[ -z "$cuda_ver" ]]; then
    echo "cpu"
    return 0
  fi

  # Claude suggestion for comparing major.minor
  local major minor
  major="${cuda_ver%%.*}"
  minor="${cuda_ver#*.}"

  if [[ "$major" -gt 13 ]] || ([[ "$major" -eq 13 ]] && [[ "$minor" -ge 0 ]]); then
    echo "cu130"
  elif [[ "$major" -eq 12 ]] && [[ "$minor" -ge 4 ]]; then
    echo "cu124"
  elif [[ "$major" -eq 12 ]] && [[ "$minor" -ge 1 ]]; then
    echo "cu121"
  elif [[ "$major" -gt 11 ]] || ([[ "$major" -eq 11 ]] && [[ "$minor" -ge 8 ]]); then
    echo "cu118"
  else
    echo "cpu"
  fi
}

torch_index_url_for_variant() {
  local v="$1"
  case "$v" in
    cpu)   echo "https://download.pytorch.org/whl/cpu" ;;
    cu118) echo "https://download.pytorch.org/whl/cu118" ;;
    cu121) echo "https://download.pytorch.org/whl/cu121" ;;
    cu124) echo "https://download.pytorch.org/whl/cu124" ;;
    cu130) echo "https://download.pytorch.org/whl/cu130" ;;
    *)     echo "" ;;
  esac
}


ensure_apt
require_sudo

sudo -n apt-get update -y
ensure_apt_pkg "$TORCH_PYTHON" || true
ensure_apt_pkg python3-venv
ensure_apt_pkg python3-pip

mkdir -p "$VENV_DIR"

if [[ ! -d "$ENV_PATH" ]]; then
  log "Creating venv: $ENV_PATH"
  "$TORCH_PYTHON" -m venv "$ENV_PATH"
else
  log "Venv already exists: $ENV_PATH"
fi

# Activate venv
# shellcheck disable=SC1090
source "$ENV_PATH/bin/activate"

# Ensure ~/.local/bin (where pipx installs uv) is in PATH
export PATH="$HOME/.local/bin:$PATH"
if ! have uv; then
  log "❌ ERROR: uv not found in PATH. Check prior python_tool.sh step"
  exit 1
fi

log "Upgrading pip/setuptools/wheel..."
pip install --upgrade pip setuptools wheel >/dev/null

# Decide variant
variant="$TORCH_VARIANT"
if [[ "$variant" == "auto" ]]; then
  variant="$(detect_cuda_variant_auto)"
fi

log "Selected torch variant: $variant"
idx_url="$(torch_index_url_for_variant "$variant")"

# Build torch spec (optional pin)
if [[ -n "$TORCH_VERSION" ]]; then
  torch_spec="torch==${TORCH_VERSION}"
  tv_spec="torchvision==${TORCH_VERSION}"
  ta_spec="torchaudio==${TORCH_VERSION}"
else
  torch_spec="torch"
  tv_spec="torchvision"
  ta_spec="torchaudio"
fi

log "Installing: $torch_spec $tv_spec $ta_spec"
if [[ -n "$idx_url" ]]; then
  uv pip install --index-url "$idx_url" "$torch_spec" "$tv_spec" "$ta_spec"
else
  # Fallback (but shouldn’t happen...)
  uv pip install "$torch_spec" "$tv_spec" "$ta_spec"
fi

if [[ -n "$EXTRA_PIP_PACKAGES" ]]; then
  log "Installing extra packages: $EXTRA_PIP_PACKAGES"
  uv pip install $EXTRA_PIP_PACKAGES
fi

# Original verification script
# log "Verifying torch install..."
# python - <<'PY'
# import torch, sys
# print("torch:", torch.__version__)
# print("python:", sys.version.split()[0])
# print("cuda available:", torch.cuda.is_available())
# print("cuda runtime (torch):", torch.version.cuda)
# if torch.cuda.is_available():
#     print("device count:", torch.cuda.device_count())
#     print("device 0:", torch.cuda.get_device_name(0))
# PY

# claude suggestion to also log
log "Verifying torch install..."
torch_verify_output=$(
python - <<'PY'
import torch, sys
print("torch:", torch.__version__)
print("python:", sys.version.split()[0])
print("cuda available:", torch.cuda.is_available())
print("cuda runtime (torch):", torch.version.cuda)
if torch.cuda.is_available():
    print("device count:", torch.cuda.device_count())
    print("device 0:", torch.cuda.get_device_name(0))
PY
)
while IFS= read -r line; do
  log "$line"
done <<< "$torch_verify_output"

log "========================"
log "✅ Torch setup completed"
log "========================"
