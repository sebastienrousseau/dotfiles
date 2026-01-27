#!/usr/bin/env bash

set -euo pipefail

out_file="${HOME}/.config/vscode/extensions.txt"

if ! command -v code >/dev/null 2>&1; then
  echo "VS Code CLI not found (code)."
  exit 1
fi

mkdir -p "$(dirname "$out_file")"
code --list-extensions | sort > "$out_file"
echo "Saved extensions to $out_file"
