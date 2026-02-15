#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Telemetry • Harden"

if [[ "${DOTFILES_TELEMETRY:-}" != "1" ]]; then
  ui_warn "Telemetry script is disabled by default."
  ui_info "Re-run with DOTFILES_TELEMETRY=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    ui_info "Disabling Ubuntu crash reporting (whoopsie/apport)..."
    sudo systemctl disable --now whoopsie 2>/dev/null || true
    sudo systemctl disable --now apport 2>/dev/null || true
    sudo systemctl mask apport 2>/dev/null || true
    ui_info "Disabling popularity-contest (if present)..."
    sudo systemctl disable --now popularity-contest 2>/dev/null || true
    ;;
  Darwin)
    ui_info "Disabling macOS analytics (manual confirmation may be required)."
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false || true
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit -bool false || true
    ;;
  *)
    ui_error "Unsupported OS for telemetry hardening."
    exit 1
    ;;
esac
