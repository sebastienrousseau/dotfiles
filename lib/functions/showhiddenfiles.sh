#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# Show hidden system and dotfile files
showhiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles YES
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}
