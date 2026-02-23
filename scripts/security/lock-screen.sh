#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
source "$SCRIPT_DIR/../dot/lib/platform.sh"

ui_init
ui_header "Lock Screen"

if [ "${DOTFILES_LOCK:-}" != "1" ]; then
  ui_warn "Lock screen" "disabled by default"
  ui_info "Re-run" "DOTFILES_LOCK=1"
  exit 1
fi

case "$(dot_platform_id)" in
  linux | wsl)
    if command -v gsettings >/dev/null; then
      ui_info "Enabling" "screen lock and idle timeout"
      gsettings set org.gnome.desktop.screensaver lock-enabled true || true
      gsettings set org.gnome.desktop.session idle-delay 300 || true
      gsettings set org.gnome.desktop.screensaver lock-delay 0 || true
    else
      ui_err "gsettings" "not found"
      exit 1
    fi
    ;;
  macos)
    ui_info "Enabling" "lock on sleep and screensaver (macOS)"
    defaults write com.apple.screensaver askForPassword -int 1 || true
    defaults write com.apple.screensaver askForPasswordDelay -int 0 || true
    # 5-minute idle timeout
    defaults -currentHost write com.apple.screensaver idleTime -int 300 || true
    ;;
  *)
    ui_err "Unsupported OS" "lock screen hardening"
    exit 1
    ;;
esac
