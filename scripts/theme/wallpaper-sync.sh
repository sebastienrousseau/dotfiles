#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Wallpaper Sync"

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

if [ ! -d "$WALLPAPER_DIR" ]; then
  ui_err "Wallpaper directory" "not found: $WALLPAPER_DIR"
  exit 1
fi

# Detect current color scheme (light/dark)
detect_mode() {
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

MODE="$(detect_mode)"

# Pick a wallpaper matching the current mode
pick_wallpaper() {
  local mode="$1"
  local files=()
  while IFS= read -r line; do
    files+=("$line")
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f -iname "*-${mode}.jpg" | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    return 1
  fi

  # Pick a random one
  if command -v shuf &>/dev/null; then
    printf '%s\n' "${files[@]}" | shuf -n 1
  else
    echo "${files[$RANDOM % ${#files[@]}]}"
  fi
}

WALLPAPER="$(pick_wallpaper "$MODE" || true)"
if [ -z "$WALLPAPER" ]; then
  ui_err "No ${MODE} wallpapers found" "$WALLPAPER_DIR"
  exit 1
fi

# Apply wallpaper based on platform and compositor
apply_wallpaper() {
  local wp="$1"
  local mode="$2"
  local wp_uri="file://${wp}"

  case "$(uname -s)" in
    Darwin)
      osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$wp\"" || true
      ;;
    Linux)
      # gsettings-based (GNOME, niri+DMS, and other freedesktop compositors)
      if command -v gsettings &>/dev/null; then
        # Find the matching pair for picture-uri and picture-uri-dark
        local light_wp dark_wp
        local base="${wp%-${mode}.jpg}"
        light_wp="${base}-light.jpg"
        dark_wp="${base}-dark.jpg"

        if [[ -f "$light_wp" ]] && [[ -f "$dark_wp" ]]; then
          gsettings set org.gnome.desktop.background picture-uri "file://${light_wp}"
          gsettings set org.gnome.desktop.background picture-uri-dark "file://${dark_wp}"
          gsettings set org.gnome.desktop.screensaver picture-uri "file://${light_wp}"
        else
          gsettings set org.gnome.desktop.background picture-uri "$wp_uri"
          gsettings set org.gnome.desktop.background picture-uri-dark "$wp_uri"
          gsettings set org.gnome.desktop.screensaver picture-uri "$wp_uri"
        fi
        gsettings set org.gnome.desktop.background picture-options "zoom"
        ui_info "Applied via" "gsettings"
      elif command -v swaybg &>/dev/null; then
        pkill swaybg || true
        swaybg -i "$wp" -m fill &
        ui_info "Applied via" "swaybg"
      elif command -v feh &>/dev/null; then
        feh --bg-fill "$wp"
        ui_info "Applied via" "feh"
      else
        ui_err "Wallpaper setter" "not found (gsettings/swaybg/feh)"
        return 1
      fi
      ;;
    *)
      ui_err "Unsupported OS" "wallpaper sync"
      return 1
      ;;
  esac
}

apply_wallpaper "$WALLPAPER" "$MODE"
ui_ok "Wallpaper applied (${MODE})" "$(basename "$WALLPAPER")"
