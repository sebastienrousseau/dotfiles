#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
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

# Hide the Desktop icons.
alias hideDesktopIcons='defaults write com.apple.finder CreateDesktop false && killall Finder'

# Open the device simulators.
alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'

# Lock the screen (when going AFK).
alias lockScreen='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'

# Disable .DS_Store files on network volumes
alias noDS='defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'

# Open the current directory in a Finder window.
alias ofd='open $PWD'

# Purging Xcode DerivedData.
alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'

# Launch Safari in Safe Mode.
alias safariSafeMode='open -a Safari --args -safe-mode'

# Show the Desktop icons.
alias showDesktopIcons='defaults write com.apple.finder CreateDesktop true && killall Finder'

# Run a screensaver on the Desktop.
alias screensaverDesktop='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'

# vp: Verify macOS Permissions.
alias vp='diskutil verifyPermissions /'

# vv: Verify macOS Volume.
alias vv='diskutil verifyvolume /'

# Turn Wi-Fi on.
alias wifiOn='networksetup -setairportpower en0 on'

# Turn Wi-Fi off.
alias wifiOff='networksetup -setairportpower en0 off'

# xcode: Launch XCode app in macOS.
alias xcode='open -a xcode'
