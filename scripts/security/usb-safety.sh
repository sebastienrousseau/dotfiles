#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot USB Safety • Security"

if [[ "${DOTFILES_USB_SAFETY:-}" != "1" ]]; then
  ui_warn "USB safety script is disabled by default."
  ui_info "Re-run with DOTFILES_USB_SAFETY=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v gsettings >/dev/null; then
      ui_info "Disabling GNOME automount for removable media..."
      gsettings set org.gnome.desktop.media-handling automount false || true
      gsettings set org.gnome.desktop.media-handling automount-open false || true
    else
      ui_error "gsettings not found."
      exit 1
    fi
    ;;
  Darwin)
    ui_info "macOS does not expose a simple CLI toggle for USB automount."
    ui_info "Use System Settings > General > Login Items > External disks."
    ;;
  *)
    ui_error "Unsupported OS for USB safety."
    exit 1
    ;;
esac
