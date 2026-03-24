#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
    --light)
      FORCE_MODE="light"
      shift
      ;;
    --dark)
      FORCE_MODE="dark"
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

# Detect current color scheme (light/dark)
detect_mode() {
  if [[ -n "${FORCE_MODE:-}" ]]; then
    echo "$FORCE_MODE"
    return
  fi
  if command -v gsettings &>/dev/null; then
    local scheme
    scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")"
    case "$scheme" in
      *dark*) echo "dark" ;;
      *) echo "light" ;;
    esac
  else
    echo "dark"
  fi
}

# Pick a random wallpaper matching mode, excluding the given path
pick_wallpaper() {
  local mode="$1"
  local exclude="${2:-}"
  local files=()
  while IFS= read -r line; do
    [[ "$line" == "$exclude" ]] && continue
    files+=("$line")
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f -iname "*-${mode}.jpg")

  if [[ ${#files[@]} -eq 0 ]]; then
    return 1
  fi

  if command -v shuf &>/dev/null; then
    printf '%s\n' "${files[@]}" | shuf -n 1
  else
    echo "${files[$RANDOM % ${#files[@]}]}"
  fi
}

apply_wallpaper() {
  local wp="$1"
  local mode="$2"

  case "$(uname -s)" in
    Darwin)
      osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$wp\"" || true
      ;;
    Linux)
      if command -v gsettings &>/dev/null; then
        local light_wp dark_wp
        local base="${wp%-${mode}.jpg}"
        light_wp="${base}-light.jpg"
        dark_wp="${base}-dark.jpg"

        if [[ -f "$light_wp" ]] && [[ -f "$dark_wp" ]]; then
          gsettings set org.gnome.desktop.background picture-uri "file://${light_wp}"
          gsettings set org.gnome.desktop.background picture-uri-dark "file://${dark_wp}"
          gsettings set org.gnome.desktop.screensaver picture-uri "file://${light_wp}"
        else
          local wp_uri="file://${wp}"
          gsettings set org.gnome.desktop.background picture-uri "$wp_uri"
          gsettings set org.gnome.desktop.background picture-uri-dark "$wp_uri"
          gsettings set org.gnome.desktop.screensaver picture-uri "$wp_uri"
        fi
        gsettings set org.gnome.desktop.background picture-options "zoom"
      elif command -v swaybg &>/dev/null; then
        pkill swaybg || true
        swaybg -i "$wp" -m fill &
      elif command -v feh &>/dev/null; then
        feh --bg-fill "$wp"
      else
        echo "No supported wallpaper setter found (gsettings/swaybg/feh)." >&2
        return 1
      fi
      ;;
    *)
      echo "Wallpaper rotation not supported on this OS." >&2
      return 1
      ;;
  esac
}

LAST_WP=""

while true; do
  MODE="$(detect_mode)"
  wp="$(pick_wallpaper "$MODE" "$LAST_WP" || true)"
  if [[ -z "$wp" ]]; then
    echo "No ${MODE} wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
  fi
  apply_wallpaper "$wp" "$MODE"
  LAST_WP="$wp"
  echo "Wallpaper applied (${MODE}): $(basename "$wp")"
  if [[ "$ONCE" -eq 1 ]]; then
    break
  fi
  sleep "$INTERVAL"
done
