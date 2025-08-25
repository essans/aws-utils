import os
import datetime
from datetime import datetime, timezone
import requests
from pathlib import Path

AWSLOGS = Path(os.environ.get("AWSLOGS", Path.home() / "AWS-UTILS/logs"))
AWSLOGS.mkdir(parents=True, exist_ok=True)

def aws_log(event: str, attribute: str, device: str = None):
    
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")

    if device is None:
        device = os.environ.get("DEVICE", "unknown")

    try:
        public_ip = requests.get("https://checkip.amazonaws.com", timeout=3).text.strip()
    except Exception:
        public_ip = "0.0.0.0"

    log_line = f"{timestamp} - {event} - {attribute} - {device}_{public_ip}/32\n"

    log_path = AWSLOGS / "aws_cli.log"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(log_line)