#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "USB Safety"

if [ "${DOTFILES_USB_SAFETY:-}" != "1" ]; then
  ui_warn "USB safety" "disabled by default"
  ui_info "Re-run" "DOTFILES_USB_SAFETY=1"
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v gsettings >/dev/null; then
      ui_info "Disabling" "GNOME automount for removable media"
      gsettings set org.gnome.desktop.media-handling automount false || true
      gsettings set org.gnome.desktop.media-handling automount-open false || true
    else
      ui_err "gsettings" "not found"
      exit 1
    fi
    ;;
  Darwin)
    ui_info "macOS" "no CLI toggle for USB automount"
    ui_info "Use" "System Settings > General > Login Items > External disks"
    ;;
  *)
    ui_err "Unsupported OS" "USB safety"
    exit 1
    ;;
esac
