#!/usr/bin/env bash
set -euo pipefail

SECRETS_DIR="$HOME/.config/chezmoi"
KEY_FILE="$SECRETS_DIR/key.txt"
CONFIG_FILE="$SECRETS_DIR/chezmoi.toml"

mkdir -p "$SECRETS_DIR"

if ! command -v age-keygen >/dev/null; then
  echo "age-keygen not found. Install 'age' first." >&2
  exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
  age-keygen -o "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Age key created at $KEY_FILE"
else
  echo "Age key already exists: $KEY_FILE"
fi

recipient=$(age-keygen -y "$KEY_FILE")

python3 - "$CONFIG_FILE" "$KEY_FILE" "$recipient" <<'PY'
import sys
import json
from pathlib import Path

config_path = Path(sys.argv[1])
key_file = sys.argv[2]
recipient = sys.argv[3]

content = ""
if config_path.exists():
    content = config_path.read_text(encoding="utf-8")

lines = content.splitlines()

# Remove existing encryption/age block
out = []
in_age = False
for line in lines:
    if line.strip().startswith("[age]"):
        in_age = True
        continue
    if in_age:
        if line.strip().startswith("["):
            in_age = False
            out.append(line)
        else:
            continue
    else:
        if line.strip().startswith("encryption ="):
            continue
        out.append(line)

# Append updated config (use json.dumps for safe string escaping)
out.append("")
out.append("encryption = \"age\"")
out.append("")
out.append("[age]")
out.append(f"identity = {json.dumps(key_file)}")
out.append(f"recipient = {json.dumps(recipient)}")

config_path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY

echo "Updated $CONFIG_FILE with age encryption settings."
