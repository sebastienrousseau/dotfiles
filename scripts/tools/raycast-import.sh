#!/usr/bin/env bash

set -euo pipefail

raycast_dir="$HOME/.config/raycast"

if [ ! -d "$raycast_dir" ]; then
  echo "Raycast config directory not found: $raycast_dir"
  exit 1
fi

echo "Import Raycast settings from: $raycast_dir"
echo "Open Raycast -> Settings -> Advanced -> Import Settings"
