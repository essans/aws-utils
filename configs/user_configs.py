from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]

SCRIPTS_DIR = PROJECT_ROOT / "scripts"
CONFIG_DIR = PROJECT_ROOT / "config"
BOOTSTRAP_DIR = PROJECT_ROOT / "bootstrap"

OUTPUTS_DIR = PROJECT_ROOT / "outputs"
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)


# ===== Update here: =====
SSH_KEYS_DIR = Path.home() / ".ssh"
REPO_DEFAULTS = SSH_KEYS_DIR / "aws_utils_defaults.yaml"
USER_TO_USE = "default"

# ===== Tailscale script not yet implemented =====
TAILSCALE_CREDENTIAL_FILE = Path.home() / ".credentials" / "credentials_tailscale"
TAILSCALE_KEY_TO_USE =  "default"








