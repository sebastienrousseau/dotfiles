#!/bin/sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451) - Homebrew tap installer.

# Check for Homebrew presence
if test "$(which brew)"; then
  # Add Taps
  brew tap 'buildit/buildit-setup' ## https://github.com/buildit/homebrew-buildit-setup
  brew tap 'buo/cask-upgrade'      ## https://github.com/buo/homebrew-cask-upgrade
  brew tap 'caskroom/cask'         ## https://github.com/caskroom/homebrew-cask
  brew tap 'caskroom/drivers'      ## https://github.com/caskroom/homebrew-drivers
  brew tap 'caskroom/fonts'        ## https://github.com/caskroom/homebrew-fonts
  brew tap 'caskroom/versions'     ## https://github.com/caskroom/homebrew-versions
  brew tap 'homebrew/autoupdate'   ## https://github.com/Homebrew/homebrew-autoupdate
  brew tap 'homebrew/bundle'       ## https://github.com/Homebrew/homebrew-bundle
  brew tap 'homebrew/cask'         ## https://github.com/Homebrew/homebrew-cask
  brew tap 'homebrew/core'         ## This is Default tap - not sure why its added - https://github.com/Homebrew/brew
  brew tap 'homebrew/services'     ## https://github.com/Homebrew/homebrew-services
  brew tap 'homebrew/versions'     ## https://github.com/Homebrew/homebrew-versions
  brew tap 'neovim/neovim'         ## https://github.com/neovim/homebrew-neovim
  brew tap 'theseal/ssh-askpass'   ## https://github.com/theseal/ssh-askpass
  brew tap 'thoughtbot/formulae'   ## https://github.com/thoughtbot/homebrew-formulae
fi

exit 0
