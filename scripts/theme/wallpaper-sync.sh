#!/bin/sh
set -e

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

if [ ! -d "$WALLPAPER_DIR" ]; then
  echo "Wallpaper directory not found: $WALLPAPER_DIR"
  exit 1
fi

pick_wallpaper() {
  find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -n 1
}

WALLPAPER="$(pick_wallpaper)"
if [ -z "$WALLPAPER" ]; then
  echo "No wallpapers found in $WALLPAPER_DIR"
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$WALLPAPER\"" || true
    ;;
  Linux)
    if command -v feh >/dev/null; then
      feh --bg-fill "$WALLPAPER"
    elif command -v swaybg >/dev/null; then
      pkill swaybg || true
      swaybg -i "$WALLPAPER" -m fill &
    else
      echo "No supported wallpaper setter found (feh/swaybg)."
      exit 1
    fi
    ;;
  *)
    echo "Wallpaper sync not supported on this OS."
    exit 1
    ;;
esac

printf "Wallpaper applied: %s\n" "$WALLPAPER"
