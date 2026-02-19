#!/usr/bin/env bash
set -euo pipefail

icon_path="${DOTFILES_LOCK_ICON:-$HOME/.config/dotfiles/lock/icon.png}"

if [[ ! -f "$icon_path" ]]; then
  echo "Lock icon not found: $icon_path" >&2
  echo "Place a PNG at that path or set DOTFILES_LOCK_ICON." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    echo "Lock icon customization is not supported via script on macOS." >&2
    exit 0
    ;;
  Linux)
    if command -v swaylock >/dev/null; then
      echo "Use: swaylock --image '$icon_path'"
    elif command -v i3lock >/dev/null; then
      echo "Use: i3lock -i '$icon_path'"
    else
      echo "No supported lock screen tool found (swaylock/i3lock)." >&2
    fi
    ;;
  *)
    echo "Unsupported OS for lock icon." >&2
    ;;
esac
