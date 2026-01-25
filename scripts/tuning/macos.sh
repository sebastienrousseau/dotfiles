#!/usr/bin/env bash
# macOS tuning (opt-in)

set -euo pipefail

if [[ "${DOTFILES_TUNING:-0}" != "1" ]]; then
  echo "Tuning is disabled. Re-run with DOTFILES_TUNING=1 to apply."
  exit 0
fi

if [[ "${DOTFILES_PROFILE:-}" != "laptop" && "${DOTFILES_PROFILE:-}" != "desktop" && "${DOTFILES_PROFILE:-}" != "server" ]]; then
  echo "DOTFILES_PROFILE is not set to a known profile. Aborting."
  exit 1
fi

echo "Applying macOS tuning..."

# Faster key repeat (requires logout/login to fully apply)
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Dock: reduce show/hide delay
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2
killall Dock >/dev/null 2>&1 || true

echo "macOS tuning complete."
