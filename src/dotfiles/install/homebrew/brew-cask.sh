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
#  Description:  Install Homebrew Casks with Homebrew
#  Homebrew-Cask extends Homebrew and brings its elegance, 
#  simplicity, and speed to macOS applications and large binaries alike.
#
#  ---------------------------------------------------------------------------


#  ---------------------------------------------------------------------------
# Get Homebrew-Cask by running the following command:
#
# brew tap caskroom/cask
#
#  ---------------------------------------------------------------------------


#  ---------------------------------------------------------------------------
# To update and maintain your cask just run:
#
# brew update && brew upgrade brew-cask && brew cleanup && brew cask cleanup
#
#  ---------------------------------------------------------------------------

#  ---------------------------------------------------------------------------
# List of macOS applications
#  ---------------------------------------------------------------------------
# brew cask install colorpicker ## removing, not found on install
brew cask install a-better-finder-rename
brew cask install adobe-creative-cloud
brew cask install alfred
brew cask install amazon-drive
brew cask install amazon-music
brew cask install android-sdk
brew cask install android-studio
brew cask install androidtool
brew cask install anvil
brew cask install appcleaner
brew cask install appcode
brew cask install applepi-baker
brew cask install arq
brew cask install atom
brew cask install bartender
brew cask install bettertouchtool
brew cask install betterzip
brew cask install brackets
brew cask install brave
brew cask install buildit-base-tools
brew cask install caffeine
brew cask install cakebrew
brew cask install carbon-copy-cloner
brew cask install charles
brew cask install cheatsheet
brew cask install chefdk
brew cask install cleanmymac
brew cask install cocoapods-app
brew cask install codekit
brew cask install colorsnapper
brew cask install coteditor
brew cask install docker
brew cask install docker-toolbox
brew cask install dropbox
brew cask install evernote
brew cask install firefox
brew cask install flickr-uploadr
brew cask install fluid
brew cask install flux
brew cask install gas-mask
brew cask install gemini
brew cask install genymotion
brew cask install gitbook-editor
brew cask install gitbox
brew cask install github-desktop
brew cask install gitkraken
brew cask install glyphs
brew cask install go2shell
brew cask install google-chrome
brew cask install google-cloud-sdk
brew cask install google-hangouts
brew cask install google-notifier
brew cask install googleappengine
brew cask install grandperspective
brew cask install hipchat
brew cask install hopper-disassembler
brew cask install imagealpha
brew cask install imageoptim
brew cask install inkscape
brew cask install ios-console
brew cask install istat-menus
brew cask install iterm2
brew cask install itsycal
brew cask install joinme
brew cask install kaleidoscope
brew cask install keka
brew cask install kindle
brew cask install lastpass
brew cask install liteicon
brew cask install little-snitch
brew cask install livereload
brew cask install macdown
brew cask install ngrok
brew cask install omnigraffle
brew cask install omniplan
brew cask install opera
brew cask install osxfuse
brew cask install parallels-desktop
brew cask install qlcolorcode
brew cask install qlimagesize
brew cask install qlmarkdown
brew cask install qlprettypatch
brew cask install qlstephen
brew cask install qlvideo
brew cask install quicklook-csv
brew cask install quicklook-json
brew cask install quicklookase
brew cask install rescuetime
brew cask install screenflick
brew cask install sequel-pro
brew cask install shiori
brew cask install sidestep
brew cask install sketch
brew cask install skitch
brew cask install skype
brew cask install slack
brew cask install smcfancontrol
brew cask install sonos
brew cask install spectacle
brew cask install spotify
brew cask install spotify-notifications
brew cask install steam
brew cask install sublime-text
brew cask install suspicious-package
brew cask install the-unarchiver
brew cask install tower
brew cask install transmit
brew cask install tunnelblick
brew cask install vagrant
brew cask install vagrant-manager
brew cask install versions
brew cask install virtualbox
brew cask install virtualbox-extension-pack
brew cask install visual-studio-code
brew cask install vlc
brew cask install webpquicklook
brew cask install webstorm
brew cask install whiskey
brew cask install xmind
brew cask install xquartz
brew cask install xscope
brew cask install xtrafinder


#  ---------------------------------------------------------------------------
# Remove outdated versions
#  ---------------------------------------------------------------------------
brew cleanup