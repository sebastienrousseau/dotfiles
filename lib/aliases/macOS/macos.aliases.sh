#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅼🅰🅲🅾🆂 🅰🅻🅸🅰🆂🅴🆂

# Recursively delete .DS_Store files.
alias clds='find . -type f -name "*.DS_Store" -ls -delete'

# Clean up LaunchServices to remove duplicates in the 'Open With' menu.
alias clls='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder'

# Empty the Trash on all mounted volumes and the main HDD.
alias emptytrash='rm -rf ~/.Trash/*'

# Hide hidden files in Finder.
alias finderHideHidden='defaults write com.apple.finder ShowAllFiles FALSE'

# Show hidden files in Finder.
alias finderShowHidden='defaults write com.apple.finder ShowAllFiles TRUE'

# Open the device simulators.
alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'

# Disable .DS_Store files on network volumes
alias noDS='defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'

# Open the current directory in a Finder window.
alias ofd='open $PWD'

# purge: Purging Xcode DerivedData.
alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'

# screensaverDesktop: Run a screensaver on the Desktop.
alias screensaverDesktop='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'

# vp: Verify macOS Permissions.
alias vp='diskutil verifyPermissions /'

# vv: Verify macOS Volume.
alias vv='diskutil verifyvolume /'

# xcode: Launch XCode app in macOS.
alias xcode='open -a xcode'
