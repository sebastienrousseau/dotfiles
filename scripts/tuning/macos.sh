#!/usr/bin/env bash
# macOS tuning (opt-in)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "macOS Tuning"

if [[ "${DOTFILES_TUNING:-0}" != "1" ]]; then
  ui_warn "Tuning" "disabled. Re-run with DOTFILES_TUNING=1"
  exit 0
fi

if [[ "${DOTFILES_PROFILE:-}" != "laptop" && "${DOTFILES_PROFILE:-}" != "desktop" && "${DOTFILES_PROFILE:-}" != "server" ]]; then
  ui_err "DOTFILES_PROFILE" "not set to known profile"
  exit 1
fi

ui_info "Applying" "macOS tuning"

# Faster key repeat (requires logout/login to fully apply)
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: use list view by default in all Finder windows
# Four-letter codes for view modes: `icnv`, `clmv`, `glyv`, `Nlsv` (list)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Restart Finder to apply changes
killall Finder >/dev/null 2>&1 || true

# Dock: reduce show/hide delay
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2
killall Dock >/dev/null 2>&1 || true

ui_ok "macOS tuning" "complete"
