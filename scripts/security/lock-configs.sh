#!/usr/bin/env bash
# MIT License
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: lock-configs.sh
# Description: Toggles immutability flags on critical configuration files.
# Usage: lock-configs [lock|unlock]

set -euo pipefail

ACTION="${1:-lock}"
CRITICAL_FILES=(
  "$HOME/.zshrc"
  "$HOME/.bashrc"
  "$HOME/.profile"
)

# Determine OS command for immutability
if [[ "$OSTYPE" == "darwin"* ]]; then
  LOCK_CMD="chflags uchg"
  UNLOCK_CMD="chflags nouchg"
  CHECK_CMD="ls -lO"
else
  # Linux (chattr +i requires root; fail loudly when sudo is missing
  # rather than printing a confusing error per file in automation)
  if command -v chattr >/dev/null; then
    if ! command -v sudo >/dev/null; then
      echo " 'sudo' not found; chattr requires root. Aborting." >&2
      exit 1
    fi
    if ! sudo -n true 2>/dev/null && [[ ! -t 0 ]]; then
      echo " sudo requires a password but no TTY is attached. Aborting." >&2
      exit 1
    fi
    LOCK_CMD="sudo chattr +i"
    UNLOCK_CMD="sudo chattr -i"
    CHECK_CMD="lsattr"
  else
    echo " 'chattr' not found. Cannot set immutability on Linux without it." >&2
    exit 1
  fi
fi

if [[ "$ACTION" == "lock" ]]; then
  echo " Locking critical configuration files..."
  CMD="$LOCK_CMD"
elif [[ "$ACTION" == "unlock" ]]; then
  echo " Unlocking critical configuration files..."
  CMD="$UNLOCK_CMD"
else
  echo "Usage: $0 [lock|unlock]"
  exit 1
fi

for file in "${CRITICAL_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    echo "Processing: $file"
    $CMD "$file" || echo "️ Failed to modify flags for $file (permission denied?)"
  fi
done

echo "Done. Environment state:"
for file in "${CRITICAL_FILES[@]}"; do
  [[ -f "$file" ]] && $CHECK_CMD "$file"
done
