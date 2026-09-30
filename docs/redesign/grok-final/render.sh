#!/bin/bash
set -euo pipefail
MANIFEST=/workspace/elite-redesign/final/html/manifest.json
CHROME="google-chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --default-background-color=0"

# Wait for fonts: load once
python3 - <<'PY'
import json
from pathlib import Path
m = json.loads(Path("/workspace/elite-redesign/final/html/manifest.json").read_text())
print(len(m))
for item in m:
    print(f"{item['w']}x{item['h']}|{item['html']}|{item['png']}")
PY
