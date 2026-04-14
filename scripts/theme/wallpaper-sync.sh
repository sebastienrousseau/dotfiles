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
CHEZMOI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
DATA_FILE="${HOME}/.dotfiles/.chezmoidata.toml"

if [ ! -d "$WALLPAPER_DIR" ]; then
  ui_err "Wallpaper directory" "not found: $WALLPAPER_DIR"
  exit 1
fi

# Detect current color scheme (light/dark)
detect_mode() {
  if command -v dms &>/dev/null; then
    local dms_mode
    dms_mode="$(dms ipc theme getMode 2>/dev/null || true)"
    case "$dms_mode" in
      dark | light)
        echo "$dms_mode"
        return 0
        ;;
    esac
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

MODE="$(detect_mode)"

current_theme() {
  if [[ -f "$CHEZMOI_CFG" ]]; then
    local chezmoi_theme
    chezmoi_theme="$(awk -F'"' '/^theme =/ {print $2}' "$CHEZMOI_CFG" | head -n 1)"
    if [[ -n "$chezmoi_theme" ]]; then
      printf '%s\n' "$chezmoi_theme"
      return 0
    fi
  fi

  if [[ -f "$DATA_FILE" ]]; then
    awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
  fi
}

wallpaper_for_theme() {
  local theme="${1:-}"
  local mode="${2:-}"
  local candidate=""
  local family=""

  [[ -n "$theme" ]] || return 1
  [[ -n "$mode" ]] || return 1

  for ext in heic jpg png; do
    candidate="$WALLPAPER_DIR/${theme}.${ext}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  family="${theme%-dark}"
  if [[ "$family" == "$theme" ]]; then
    family="${theme%-light}"
  fi
  for ext in heic jpg png; do
    candidate="$WALLPAPER_DIR/${family}-${mode}.${ext}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

theme_wallpaper_pair() {
  local theme="${1:-}"
  local family=""
  local light_wp=""
  local dark_wp=""

  [[ -n "$theme" ]] || return 1

  family="${theme%-dark}"
  if [[ "$family" == "$theme" ]]; then
    family="${theme%-light}"
  fi

  light_wp="$(wallpaper_for_theme "${family}-light" "light" || true)"
  dark_wp="$(wallpaper_for_theme "${family}-dark" "dark" || true)"

  if [[ -n "$light_wp" && -n "$dark_wp" ]]; then
    printf '%s\n%s\n' "$light_wp" "$dark_wp"
    return 0
  fi

  return 1
}

# Pick a wallpaper matching the current mode
pick_wallpaper() {
  local mode="$1"
  local theme="${2:-}"
  local files=()

  if [[ -n "$theme" ]]; then
    local matched
    matched="$(wallpaper_for_theme "$theme" "$mode" || true)"
    if [[ -n "$matched" ]]; then
      printf '%s\n' "$matched"
      return 0
    fi
  fi

  while IFS= read -r line; do
    files+=("$line")
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*-${mode}.jpg" -o -iname "*-${mode}.png" -o -iname "*-${mode}.heic" \) | sort)

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

THEME="$(current_theme || true)"
WALLPAPER="$(pick_wallpaper "$MODE" "$THEME" || true)"
if [ -z "$WALLPAPER" ]; then
  ui_err "No ${MODE} wallpapers found" "$WALLPAPER_DIR"
  exit 1
fi

# Convert .heic to .png on Linux (HEIC not universally supported)
ensure_linux_compatible() {
  local wp="$1"
  [[ "$(uname -s)" == "Linux" ]] || {
    printf '%s\n' "$wp"
    return
  }
  [[ "${wp##*.}" == "heic" ]] || {
    printf '%s\n' "$wp"
    return
  }

  local png="${wp%.heic}.png"
  if [[ -f "$png" ]] && [[ "$png" -nt "$wp" ]]; then
    printf '%s\n' "$png"
    return
  fi

  if command -v magick &>/dev/null; then
    magick "$wp" -quality 95 "$png" 2>/dev/null && {
      printf '%s\n' "$png"
      return
    }
  elif command -v heif-convert &>/dev/null; then
    heif-convert "$wp" "$png" 2>/dev/null && {
      printf '%s\n' "$png"
      return
    }
  elif command -v convert &>/dev/null; then
    convert "$wp" "$png" 2>/dev/null && {
      printf '%s\n' "$png"
      return
    }
  fi

  # Fallback: use original and hope the DE supports it
  printf '%s\n' "$wp"
}

# Apply wallpaper based on platform and compositor
apply_wallpaper() {
  local wp="$1"
  local mode="$2"

  # Convert HEIC to PNG on Linux if needed
  wp="$(ensure_linux_compatible "$wp")"
  local wp_uri="file://${wp}"

  case "$(uname -s)" in
    Darwin)
      osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$wp\"" || true
      ;;
    Linux)
      # Niri + DMS/Quickshell uses its own wallpaper state.
      if command -v dms &>/dev/null; then
        local dms_result current_outputs output current_dms_mode light_wp dark_wp
        dms_result="$(dms ipc wallpaper set "$wp" 2>/dev/null || true)"
        if [[ "$dms_result" == SUCCESS:* ]]; then
          ui_info "Applied via" "dms ipc wallpaper set"
        elif [[ "$dms_result" == ERROR:\ Per-monitor\ mode\ enabled* ]]; then
          current_outputs="$(dms ipc outputs current 2>/dev/null | tr -d '[]"')"
          for output in ${current_outputs//,/ }; do
            [[ -n "$output" ]] || continue
            dms ipc wallpaper setFor "$output" "$wp" >/dev/null 2>&1 || true
          done
          ui_info "Applied via" "dms ipc wallpaper setFor"
        else
          ui_warn "DMS wallpaper" "set failed, falling back"
        fi

        # Keep DMS light/dark wallpaper slots aligned with the theme family.
        if [[ -n "${THEME:-}" ]] && mapfile -t _pair < <(theme_wallpaper_pair "$THEME"); then
          light_wp="${_pair[0]:-}"
          dark_wp="${_pair[1]:-}"
          current_dms_mode="$(dms ipc theme getMode 2>/dev/null || printf '%s\n' "$mode")"

          if [[ -n "$light_wp" && -n "$dark_wp" ]]; then
            dms ipc theme light >/dev/null 2>&1 || true
            dms ipc wallpaper set "$light_wp" >/dev/null 2>&1 || true

            dms ipc theme dark >/dev/null 2>&1 || true
            dms ipc wallpaper set "$dark_wp" >/dev/null 2>&1 || true

            if [[ "$current_dms_mode" == "light" ]]; then
              dms ipc theme light >/dev/null 2>&1 || true
            else
              dms ipc theme dark >/dev/null 2>&1 || true
            fi
            ui_info "DMS pair" "$(basename "$light_wp"), $(basename "$dark_wp")"
          fi
        fi
      fi

      # gsettings-based desktop state for GTK/freedesktop consumers
      if command -v gsettings &>/dev/null; then
        # Find the matching pair for picture-uri and picture-uri-dark
        local light_wp dark_wp base ext
        ext="${wp##*.}"
        base="${wp%-${mode}.${ext}}"
        if [[ -f "${base}-light.${ext}" ]] && [[ -f "${base}-dark.${ext}" ]]; then
          light_wp="${base}-light.${ext}"
          dark_wp="${base}-dark.${ext}"
        elif [[ -f "${base}-light.heic" ]] && [[ -f "${base}-dark.heic" ]]; then
          light_wp="${base}-light.heic"
          dark_wp="${base}-dark.heic"
        elif [[ -f "${base}-light.jpg" ]] && [[ -f "${base}-dark.jpg" ]]; then
          light_wp="${base}-light.jpg"
          dark_wp="${base}-dark.jpg"
        elif [[ -f "${base}-light.png" ]] && [[ -f "${base}-dark.png" ]]; then
          light_wp="${base}-light.png"
          dark_wp="${base}-dark.png"
        else
          light_wp=""
          dark_wp=""
        fi

        if [[ -n "$light_wp" ]] && [[ -n "$dark_wp" ]]; then
          light_wp="$(ensure_linux_compatible "$light_wp")"
          dark_wp="$(ensure_linux_compatible "$dark_wp")"
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
if [[ -n "$THEME" ]]; then
  ui_ok "Wallpaper applied (${MODE})" "$(basename "$WALLPAPER") ← $THEME"
else
  ui_ok "Wallpaper applied (${MODE})" "$(basename "$WALLPAPER")"
fi
