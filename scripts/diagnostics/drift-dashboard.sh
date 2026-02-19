#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

if ! command -v chezmoi >/dev/null; then
  ui_err "chezmoi" "not found"
  exit 1
fi

ui_header "Dotfiles Drift Dashboard"

status=$(chezmoi status || true)
if [[ -z "$status" ]]; then
  ui_ok "Clean" "no local drift detected"
  exit 0
fi

echo ""
ui_header "Changed files"
printf '%s\n' "$status"

count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
echo ""
ui_info "Total" "$count"

if [[ "${DOTFILES_DRIFT_SHOW_DIFF:-0}" = "1" ]]; then
  echo ""
  ui_header "Diff (excluding scripts/install/tests)"
  chezmoi diff --exclude scripts --exclude install --exclude tests || true
fi
