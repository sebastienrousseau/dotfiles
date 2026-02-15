#!/usr/bin/env bash
# MIT License
# Copyright (c) 2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: lock-configs.sh
# Description: Toggles immutability flags on critical configuration files.
# Usage: lock-configs [lock|unlock]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Lock Configs • Security"

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
  # Linux (requires root usually, but we'll try)
  if command -v chattr >/dev/null; then
    LOCK_CMD="sudo chattr +i"
    UNLOCK_CMD="sudo chattr -i"
    CHECK_CMD="lsattr"
  else
    ui_error "'chattr' not found. Cannot set immutability on Linux without it."
    exit 1
  fi
fi

if [[ "$ACTION" == "lock" ]]; then
  ui_info "Locking critical configuration files..."
  CMD="$LOCK_CMD"
elif [[ "$ACTION" == "unlock" ]]; then
  ui_info "Unlocking critical configuration files..."
  CMD="$UNLOCK_CMD"
else
  ui_error "Usage: $0 [lock|unlock]"
  exit 1
fi

for file in "${CRITICAL_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    ui_info "Processing: $file"
    $CMD "$file" || ui_warn "Failed to modify flags for $file (permission denied?)"
  fi
done

ui_section "Environment State"
for file in "${CRITICAL_FILES[@]}"; do
  [[ -f "$file" ]] && $CHECK_CMD "$file"
done
