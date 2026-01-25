#!/bin/sh
set -e

if [ "${DOTFILES_USB_SAFETY:-}" != "1" ]; then
  echo "USB safety script is disabled by default."
  echo "Re-run with DOTFILES_USB_SAFETY=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v gsettings >/dev/null; then
      echo "Disabling GNOME automount for removable media..."
      gsettings set org.gnome.desktop.media-handling automount false || true
      gsettings set org.gnome.desktop.media-handling automount-open false || true
    else
      echo "gsettings not found."
      exit 1
    fi
    ;;
  Darwin)
    echo "macOS does not expose a simple CLI toggle for USB automount."
    echo "Use System Settings > General > Login Items > External disks."
    ;;
  *)
    echo "Unsupported OS for USB safety."
    exit 1
    ;;
esac
