#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/platform.sh"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in --dry-run | -n) DRY_RUN=1 ;; esac
done
_run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then ui_info "[dry-run]" "$*"; else "$@"; fi
}

ui_init
ui_header "Telemetry"

if [[ "$DRY_RUN" -eq 1 ]]; then
  ui_info "Mode" "dry-run (no changes will be made)"
elif [ "${DOTFILES_TELEMETRY:-}" != "1" ]; then
  ui_warn "Telemetry" "disabled by default"
  ui_info "Re-run" "DOTFILES_TELEMETRY=1"
  exit 1
fi

case "$(dot_platform_id)" in
  linux | wsl)
    ui_info "Disabling" "Ubuntu crash reporting (whoopsie/apport)"
    _run_cmd sudo systemctl disable --now whoopsie 2>/dev/null || true
    _run_cmd sudo systemctl disable --now apport 2>/dev/null || true
    _run_cmd sudo systemctl mask apport 2>/dev/null || true
    ui_info "Disabling" "popularity-contest"
    _run_cmd sudo systemctl disable --now popularity-contest 2>/dev/null || true
    ;;
  macos)
    ui_info "Disabling" "macOS analytics"
    _run_cmd sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false || true
    _run_cmd sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit -bool false || true
    ;;
  *)
    ui_err "Unsupported OS" "telemetry kill"
    exit 1
    ;;
esac
