#!/usr/bin/env bash
set -euo pipefail

THEME="${DOTFILES_ICON_THEME:-Papirus}"

case "$(uname -s)" in
  Darwin)
    if command -v fileicon >/dev/null; then
      echo "Use: fileicon set <path> <icon.icns> to apply custom icons."
    else
      echo "fileicon not found. Install it via brew (brew install fileicon)." >&2
    fi
    ;;
  Linux)
    if command -v gsettings >/dev/null; then
      gsettings set org.gnome.desktop.interface icon-theme "$THEME" || true
      echo "Set GNOME icon theme to $THEME."
    else
      echo "gsettings not found. Set icon theme in your DE settings." >&2
    fi
    ;;
  *)
    echo "Unsupported OS for icon theming." >&2
    ;;
esac
