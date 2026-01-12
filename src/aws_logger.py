
# Wanted a bit more control over logging, screen handling so created a lightweight function
# Needs a bit of refinement but for now does what I need it to.

import os
from datetime import datetime, timezone, timedelta
import requests
from pathlib import Path


AWSLOGS = Path(f"~/logs/aws").expanduser()
AWSLOGS.mkdir(parents=True, exist_ok=True)

#unset AWS_LOG_DIR

def aws_log(event: str, attribute: str, device: str | None = None, verbose: bool = False) -> None:

    # timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    timestamp = datetime.now(timezone(timedelta(hours=-5))).strftime("%Y-%m-%dT%H:%M:%S")

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

    if verbose:
        print(f"{attribute}")