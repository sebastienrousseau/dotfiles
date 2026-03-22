#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/platform.sh"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in --dry-run | -n) DRY_RUN=1 ;; esac
done
_run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then ui_info "[dry-run]" "$*"; else "$@"; fi
}

ui_init
ui_header "USB Safety"

if [[ "$DRY_RUN" -eq 1 ]]; then
  ui_info "Mode" "dry-run (no changes will be made)"
elif [ "${DOTFILES_USB_SAFETY:-}" != "1" ]; then
  ui_warn "USB safety" "disabled by default"
  ui_info "Re-run" "DOTFILES_USB_SAFETY=1"
  exit 1
fi

case "$(dot_platform_id)" in
  linux | wsl)
    if command -v gsettings >/dev/null; then
      ui_info "Disabling" "GNOME automount for removable media"
      _run_cmd gsettings set org.gnome.desktop.media-handling automount false || true
      _run_cmd gsettings set org.gnome.desktop.media-handling automount-open false || true
    else
      ui_err "gsettings" "not found"
      exit 1
    fi
    ;;
  macos)
    ui_info "macOS" "no CLI toggle for USB automount"
    ui_info "Use" "System Settings > General > Login Items > External disks"
    ;;
  *)
    ui_err "Unsupported OS" "USB safety"
    exit 1
    ;;
esac
