#!/usr/bin/env bash
set -euo pipefail

THEME="${DOTFILES_CURSOR_THEME:-Bibata-Modern-Ice}"
SIZE="${DOTFILES_CURSOR_SIZE:-24}"

case "$(uname -s)" in
  Darwin)
    echo "Cursor theming is not supported via script on macOS." >&2
    exit 0
    ;;
  Linux)
    if command -v gsettings >/dev/null; then
      gsettings set org.gnome.desktop.interface cursor-theme "$THEME" || true
      gsettings set org.gnome.desktop.interface cursor-size "$SIZE" || true
      echo "Set GNOME cursor theme to $THEME ($SIZE)."
    else
      echo "gsettings not found. Set cursor theme in your DE settings." >&2
    fi
    ;;
  *)
    echo "Unsupported OS for cursor theming." >&2
    ;;
esac
