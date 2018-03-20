#!/bin/sh

#  ---------------------------------------------------------------------------
#
#  ______      _  ______ _ _           
#  |  _  \    | | |  ___(_) |          
#  | | | |___ | |_| |_   _| | ___  ___ 
#  | | | / _ \| __|  _| | | |/ _ \/ __|
#  | |/ / (_) | |_| |   | | |  __/\__ \
#  |___/ \___/ \__\_|   |_|_|\___||___/
#                                                                            
#  Description:  Install Homebrew Taps with Homebrew
#  Taps are external sources of Homebrew formulae and/or
#  external commands.
#
#  ---------------------------------------------------------------------------


#  ---------------------------------------------------------------------------
# Add Taps
#  ---------------------------------------------------------------------------

brew tap 'buildit/buildit-setup' ## https://github.com/buildit/homebrew-buildit-setup
brew tap 'buo/cask-upgrade' ## https://github.com/buo/homebrew-cask-upgrade
brew tap 'caskroom/cask' ## https://caskroom.github.io/
brew tap 'caskroom/drivers' ## https://github.com/caskroom/homebrew-drivers
brew tap 'ethereum/ethereum' ## https://github.com/ethereum/homebrew-ethereum
brew tap 'homebrew/bundle'  ## https://github.com/Homebrew/homebrew-bundle
brew tap 'homebrew/core' ## This is Default tap - not sure why its added - https://github.com/Homebrew/brew
brew tap 'homebrew/services' ## https://github.com/Homebrew/homebrew-services
brew tap 'neovim/neovim' ## https://github.com/neovim/homebrew-neovim
brew tap 'theseal/ssh-askpass' ## https://github.com/theseal/ssh-askpass
brew tap 'thoughtbot/formulae' ## https://github.com/thoughtbot/homebrew-formulae 
brew tap 'raggi/ale' ## limited info on whats availabl in tap - https://github.com/raggi/homebrew-ale
brew tap 'caskroom/versions' ## https://github.com/caskroom/homebrew-versions