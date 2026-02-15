#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Lock Screen • Security"

if [[ "${DOTFILES_LOCK:-}" != "1" ]]; then
  ui_warn "Lock screen script is disabled by default."
  ui_info "Re-run with DOTFILES_LOCK=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v gsettings >/dev/null; then
      ui_info "Enabling screen lock and idle timeout..."
      gsettings set org.gnome.desktop.screensaver lock-enabled true || true
      gsettings set org.gnome.desktop.session idle-delay 300 || true
      gsettings set org.gnome.desktop.screensaver lock-delay 0 || true
    else
      ui_error "gsettings not found."
      exit 1
    fi
    ;;
  Darwin)
    ui_info "Enabling lock on sleep and screensaver (macOS)..."
    defaults write com.apple.screensaver askForPassword -int 1 || true
    defaults write com.apple.screensaver askForPasswordDelay -int 0 || true
    # 5-minute idle timeout
    defaults -currentHost write com.apple.screensaver idleTime -int 300 || true
    ;;
  *)
    ui_error "Unsupported OS for lock screen hardening."
    exit 1
    ;;
esac
