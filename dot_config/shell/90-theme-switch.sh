#!/usr/bin/env bash
# Detect system appearance (dark/light) and export THEME_MODE
# Consumed by starship, bat, delta, fzf, and other theme-aware tools
#
# macOS: reads AppleInterfaceStyle from user defaults
# Linux: checks DBUS org.freedesktop.portal.Settings color-scheme
#
# Performance: Caches result for 1 hour to avoid system calls on every shell startup

detect_theme_mode() {
  local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles_theme_mode"
  local cache_ttl=3600  # 1 hour in seconds

  # Check if cache exists and is fresh
  if [[ -f "$cache_file" ]]; then
    local cache_age
    local now
    now=$(date +%s)
    # macOS uses -f %m, Linux uses -c %Y for mtime
    if [[ "$(uname -s)" == "Darwin" ]]; then
      cache_age=$((now - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
    else
      cache_age=$((now - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
    fi
    if [[ $cache_age -lt $cache_ttl ]]; then
      THEME_MODE="$(cat "$cache_file")"
      export THEME_MODE
      return
    fi
  fi

  # Ensure cache directory exists
  mkdir -p "$(dirname "$cache_file")"

  case "$(uname -s)" in
    Darwin)
      if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
        export THEME_MODE="dark"
      else
        export THEME_MODE="light"
      fi
      ;;
    Linux)
      if command -v busctl >/dev/null 2>&1; then
        local scheme
        scheme="$(busctl --user get-property \
          org.freedesktop.portal.Desktop \
          /org/freedesktop/portal/desktop \
          org.freedesktop.portal.Settings \
          Read "org.freedesktop.appearance" "color-scheme" 2>/dev/null |
          grep -o '[0-9]*$')"
        if [ "$scheme" = "1" ]; then
          export THEME_MODE="dark"
        else
          export THEME_MODE="light"
        fi
      else
        export THEME_MODE="dark"
      fi
      ;;
    *)
      export THEME_MODE="dark"
      ;;
  esac

  # Cache the result
  echo "$THEME_MODE" > "$cache_file"
}

detect_theme_mode
