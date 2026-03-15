# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Show hidden system and dotfile files
showhiddenfiles() {
  # macOS only
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "showhiddenfiles: macOS only" >&2
    return 1
  fi

  defaults write com.apple.Finder AppleShowAllFiles YES
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}
