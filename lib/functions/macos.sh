#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2022. All rights reserved
# License: MIT

# 🅼🅰🅲🅾🆂 🅿🅻🆄🅶🅸🅽🅶 🅰🅻🅸🅰🆂🅴🆂

alias clds='find . -type f -name "*.DS_Store" -ls -delete'                                                                                                                                 # clds: Recursively delete .DS_Store files.
alias clls='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder' # clls:  Clean up LaunchServices to remove duplicates in the 'Open With' menu.
alias emptytrash='rm -rf ~/.Trash/*'                                                                                                                                                       # Empty the Trash on all mounted volumes and the main HDD.
alias finderHideHidden='defaults write com.apple.finder ShowAllFiles FALSE'                                                                                                                # finderHideHidden: Hide hidden files in Finder.
alias finderShowHidden='defaults write com.apple.finder ShowAllFiles TRUE'                                                                                                                 # finderShowHidden: Show hidden files in Finder.
alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'                                                                                                  # iphone: Open the device simulators.
alias noDS='defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
alias ofd='open $PWD'                                                                                                                                    # Open the current directory in a Finder window.
alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'                                                                                             # purge: Purging Xcode DerivedData.
alias screensaverDesktop='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background' # screensaverDesktop: Run a screensaver on the Desktop.
alias vp='diskutil verifyPermissions /'                                                                                                                  # vp: Verify macOS Permissions.
alias vv='diskutil verifyvolume /'                                                                                                                       # vv: Verify macOS Volume.
alias xcode='open -a xcode'                                                                                                                              # xcode: Launch XCode app in macOS.

# 🅼🅰🅲🅾🆂 🅿🅻🆄🅶🅸🅽🅶 🅵🆄🅽🅲🆃🅸🅾🅽🆂

# Erases purgeable disk space with 0s on the selected disk
freespace() {
  if [[ -z "$1" ]]; then
    echo "Usage: $0 <disk>"
    echo "Example: $0 /dev/disk1s1"
    echo
    echo "Possible disks:"
    df -h | awk 'NR == 1 || /^\/dev\/disk/'
    return 1
  fi

  echo "Cleaning purgeable files from disk: $1 ...."
  diskutil secureErase freespace 0 "$1"
}

mp() {
  # Don't let Preview.app steal focus if the man page doesn't exist
  man -w "$@" >/dev/null 2>&1 || man -t "$@" | open -f -a Preview || man "$@"
}

ql() {
  (($# > 0)) && qlmanage -p "$*" &>/dev/null &
}
