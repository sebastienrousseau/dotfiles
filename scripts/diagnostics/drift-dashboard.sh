#!/usr/bin/env bash
set -euo pipefail

if ! command -v chezmoi >/dev/null; then
  echo "chezmoi not found." >&2
  exit 1
fi

echo "=== Dotfiles Drift Dashboard ==="

status=$(chezmoi status || true)
if [[ -z "$status" ]]; then
  echo "Clean: no local drift detected."
  exit 0
fi

echo "\nChanged files:"
printf '%s\n' "$status"

count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
echo "\nTotal: $count"

if [[ "${DOTFILES_DRIFT_SHOW_DIFF:-0}" = "1" ]]; then
  echo "\n--- Diff (excluding scripts/install/tests) ---"
  chezmoi diff --exclude scripts --exclude install --exclude tests || true
fi
