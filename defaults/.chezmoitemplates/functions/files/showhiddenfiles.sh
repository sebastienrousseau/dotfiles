# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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
