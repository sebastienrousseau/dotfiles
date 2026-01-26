#!/usr/bin/env bash
# Detect system appearance (dark/light) and export THEME_MODE
# Consumed by starship, bat, delta, fzf, and other theme-aware tools
#
# macOS: reads AppleInterfaceStyle from user defaults
# Linux: checks DBUS org.freedesktop.portal.Settings color-scheme

detect_theme_mode() {
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
}

detect_theme_mode
