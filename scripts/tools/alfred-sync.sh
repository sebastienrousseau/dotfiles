#!/usr/bin/env bash

set -euo pipefail

prefs_dir="$HOME/.config/alfred"

if [ ! -d "$prefs_dir" ]; then
  echo "Alfred prefs directory not found: $prefs_dir"
  exit 1
fi

echo "Point Alfred preferences to: $prefs_dir"
echo "Alfred -> Preferences -> Advanced -> Set preferences folder"
