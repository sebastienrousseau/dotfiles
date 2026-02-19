#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
INTERVAL="${DOTFILES_WALLPAPER_INTERVAL:-300}"
ONCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --once)
      ONCE=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "Wallpaper directory not found: $WALLPAPER_DIR" >&2
  exit 1
fi

pick_wallpaper() {
  local files
  files=()
  while IFS= read -r line; do
    files+=("$line")
  done < <(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \))
  if [[ ${#files[@]} -eq 0 ]]; then
    return 1
  fi
  if command -v shuf &>/dev/null; then
    printf '%s\n' "${files[@]}" | shuf -n 1
  else
    # macOS fallback using $RANDOM
    echo "${files[$RANDOM % ${#files[@]}]}"
  fi
}

apply_wallpaper() {
  local wp="$1"
  case "$(uname -s)" in
    Darwin)
      osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$wp\"" || true
      ;;
    Linux)
      if command -v feh >/dev/null; then
        feh --bg-fill "$wp"
      elif command -v swaybg >/dev/null; then
        pkill swaybg || true
        swaybg -i "$wp" -m fill &
      else
        echo "No supported wallpaper setter found (feh/swaybg)." >&2
        return 1
      fi
      ;;
    *)
      echo "Wallpaper rotation not supported on this OS." >&2
      return 1
      ;;
  esac
}

while true; do
  wp=$(pick_wallpaper)
  if [[ -z "$wp" ]]; then
    echo "No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
  fi
  apply_wallpaper "$wp"
  echo "Wallpaper applied: $wp"
  if [[ "$ONCE" -eq 1 ]]; then
    break
  fi
  sleep "$INTERVAL"
done
