#!/usr/bin/env bash
# Detect system appearance (dark/light) and export THEME_MODE
# Consumed by starship, bat, delta, fzf, and other theme-aware tools
#
# macOS: reads AppleInterfaceStyle from user defaults
# Linux: checks DBUS org.freedesktop.portal.Settings color-scheme
#
# Performance: Caches result for 1 hour. Uses fast file existence check
# before any timestamp comparisons to minimize system calls.

detect_theme_mode() {
  local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles_theme_mode"
  local cache_ttl=3600  # 1 hour in seconds

  # Fast path: if cache exists, check if it's fresh
  if [[ -f "$cache_file" ]]; then
    # Use zsh's EPOCHSECONDS if available (no subprocess), else date
    local now
    if [[ -n "${EPOCHSECONDS:-}" ]]; then
      now=$EPOCHSECONDS
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
      # zsh can load datetime module
      zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null
      now=${EPOCHSECONDS:-$(date +%s)}
    else
      now=$(date +%s)
    fi

    # Get file mtime - use zsh stat module if available
    local mtime
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      zmodload -F zsh/stat b:zstat 2>/dev/null
      if (( ${+functions[zstat]} )) || (( ${+builtins[zstat]} )); then
        mtime=$(zstat +mtime "$cache_file" 2>/dev/null)
      fi
    fi

    # Fallback to external stat if zsh module unavailable
    if [[ -z "${mtime:-}" ]]; then
      case "${OSTYPE:-$(uname -s)}" in
        darwin*|Darwin) mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0) ;;
        *) mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ;;
      esac
    fi

    if (( now - mtime < cache_ttl )); then
      THEME_MODE="$(<"$cache_file")"
      export THEME_MODE
      return 0
    fi
  fi

  # Ensure cache directory exists
  [[ -d "${cache_file%/*}" ]] || mkdir -p "${cache_file%/*}"

  # Detect theme based on OS
  case "${OSTYPE:-$(uname -s)}" in
    darwin*|Darwin)
      if defaults read -g AppleInterfaceStyle &>/dev/null; then
        THEME_MODE="dark"
      else
        THEME_MODE="light"
      fi
      ;;
    linux*|Linux)
      if command -v busctl &>/dev/null; then
        local scheme
        scheme="$(busctl --user get-property \
          org.freedesktop.portal.Desktop \
          /org/freedesktop/portal/desktop \
          org.freedesktop.portal.Settings \
          Read "org.freedesktop.appearance" "color-scheme" 2>/dev/null |
          grep -o '[0-9]*$')" || true
        [[ "$scheme" == "1" ]] && THEME_MODE="dark" || THEME_MODE="light"
      else
        THEME_MODE="dark"  # Default for headless Linux
      fi
      ;;
    *)
      THEME_MODE="dark"
      ;;
  esac

  export THEME_MODE
  printf '%s' "$THEME_MODE" > "$cache_file"
}

detect_theme_mode
