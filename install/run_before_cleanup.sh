#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# This script removes legacy files from the home directory.

set -euo pipefail

FILES_TO_REMOVE=(
  "$HOME/aliases.txt"
  "$HOME/functions.txt"
  "$HOME/check_links.py"
  "$HOME/Dockerfile.test"
  "$HOME/install.sh"
  "$HOME/LICENSE"
  "$HOME/README.md"
)

for file in "${FILES_TO_REMOVE[@]}"; do
  if [ -f "$file" ]; then
    echo "Removing legacy file: $file"
    rm "$file"
  fi
done
