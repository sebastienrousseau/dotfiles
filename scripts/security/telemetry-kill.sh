#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Telemetry"

if [ "${DOTFILES_TELEMETRY:-}" != "1" ]; then
  ui_warn "Telemetry" "disabled by default"
  ui_info "Re-run" "DOTFILES_TELEMETRY=1"
  exit 1
fi

case "$(uname -s)" in
  Linux)
    ui_info "Disabling" "Ubuntu crash reporting (whoopsie/apport)"
    sudo systemctl disable --now whoopsie 2>/dev/null || true
    sudo systemctl disable --now apport 2>/dev/null || true
    sudo systemctl mask apport 2>/dev/null || true
    ui_info "Disabling" "popularity-contest"
    sudo systemctl disable --now popularity-contest 2>/dev/null || true
    ;;
  Darwin)
    ui_info "Disabling" "macOS analytics"
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false || true
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit -bool false || true
    ;;
  *)
    ui_err "Unsupported OS" "telemetry kill"
    exit 1
    ;;
esac
