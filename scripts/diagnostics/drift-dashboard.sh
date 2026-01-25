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

printf "\nChanged files:\n"
printf '%s\n' "$status"

count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
printf "\nTotal: %s\n" "$count"

if [[ "${DOTFILES_DRIFT_SHOW_DIFF:-0}" = "1" ]]; then
  printf "\n--- Diff (excluding scripts/install/tests) ---\n"
  chezmoi diff --exclude scripts --exclude install --exclude tests || true
fi
