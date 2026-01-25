#!/bin/sh
set -e

if [ "${DOTFILES_LOCK:-}" != "1" ]; then
  echo "Lock screen script is disabled by default."
  echo "Re-run with DOTFILES_LOCK=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v gsettings >/dev/null; then
      echo "Enabling screen lock and idle timeout..."
      gsettings set org.gnome.desktop.screensaver lock-enabled true || true
      gsettings set org.gnome.desktop.session idle-delay 300 || true
      gsettings set org.gnome.desktop.screensaver lock-delay 0 || true
    else
      echo "gsettings not found."
      exit 1
    fi
    ;;
  Darwin)
    echo "Enabling lock on sleep and screensaver (macOS)..."
    defaults write com.apple.screensaver askForPassword -int 1 || true
    defaults write com.apple.screensaver askForPasswordDelay -int 0 || true
    # 5-minute idle timeout
    defaults -currentHost write com.apple.screensaver idleTime -int 300 || true
    ;;
  *)
    echo "Unsupported OS for lock screen hardening."
    exit 1
    ;;
esac
