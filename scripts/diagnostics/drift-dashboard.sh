#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

if ! command -v chezmoi >/dev/null; then
  ui_error "chezmoi not found."
  exit 1
fi

ui_logo_dot "Dot Drift • Dashboard"

status=$(chezmoi status || true)
if [[ -z "$status" ]]; then
  ui_success "Clean: no local drift detected."
  exit 0
fi

ui_section "Changed Files"
printf '%s\n' "$status"

count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
printf "\n"
ui_key_value "Total" "$count"

if [[ "${DOTFILES_DRIFT_SHOW_DIFF:-0}" = "1" ]]; then
  ui_section "Diff (excluding scripts/install/tests)"
  chezmoi diff --exclude scripts --exclude install --exclude tests || true
fi
