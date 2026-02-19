#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Wallpaper Sync"

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

if [ ! -d "$WALLPAPER_DIR" ]; then
  ui_err "Wallpaper directory" "not found: $WALLPAPER_DIR"
  exit 1
fi

pick_wallpaper() {
  find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -n 1
}

WALLPAPER="$(pick_wallpaper)"
if [ -z "$WALLPAPER" ]; then
  ui_err "No wallpapers found" "$WALLPAPER_DIR"
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$WALLPAPER\"" || true
    ;;
  Linux)
    if command -v feh >/dev/null; then
      ui_info "Applying" "feh --bg-fill"
      feh --bg-fill "$WALLPAPER"
    elif command -v swaybg >/dev/null; then
      ui_info "Applying" "swaybg -m fill"
      pkill swaybg || true
      swaybg -i "$WALLPAPER" -m fill &
    else
      ui_err "Wallpaper setter" "not found (feh/swaybg)"
      exit 1
    fi
    ;;
  *)
    ui_err "Unsupported OS" "wallpaper sync"
    exit 1
    ;;
esac

ui_ok "Wallpaper applied" "$WALLPAPER"
