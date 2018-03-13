#!/usr/bin/env bash

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Add Taps
# brew tap 'aspnet/dnx' ## OBSOLETE - https://github.com/aspnet/homebrew-dnx
brew tap 'buildit/buildit-setup' ## https://github.com/buildit/homebrew-buildit-setup
brew tap 'buo/cask-upgrade' ## https://github.com/buo/homebrew-cask-upgrade
brew tap 'caskroom/cask' ## https://caskroom.github.io/
brew tap 'caskroom/drivers' ## https://github.com/caskroom/homebrew-drivers
brew tap 'ethereum/ethereum' ## https://github.com/ethereum/homebrew-ethereum
brew tap 'homebrew/bundle'  ## https://github.com/Homebrew/homebrew-bundle
# brew tap 'homebrew/completions' ## DEPRECIATED - moved to core - https://github.com/Homebrew/homebrew-completions
brew tap 'homebrew/core' ## This is Default tap - not sure why its added - https://github.com/Homebrew/brew
# brew tap 'homebrew/dupes' ## DEPRECIATED - moved to core - https://github.com/Homebrew/homebrew-dupes
# brew tap 'homebrew/fuse' ## DEPRECIATED - moved to core - https://github.com/Homebrew/homebrew-fuse
# brew tap 'homebrew/science' ## DEPRECIATED - moved to core - https://github.com/Homebrew/homebrew-science
brew tap 'homebrew/services' ## https://github.com/Homebrew/homebrew-services
# brew tap 'homebrew/versions' ## DEPRECIATED - moved to core - https://github.com/Homebrew/homebrew-versions
brew tap 'neovim/neovim' ## https://github.com/neovim/homebrew-neovim
# brew tap 'phinze/cask' ## removing cant find info on this tap
# brew tap 'raggi/ale' ## limited info on whats availabl in tap - https://github.com/raggi/homebrew-ale
brew tap 'theseal/ssh-askpass' ## https://github.com/theseal/ssh-askpass
brew tap 'thoughtbot/formulae' ## https://github.com/thoughtbot/homebrew-formulae 

# Add binaries
brew install ack
brew install adns
brew install aircrack-ng
brew install ansible
brew install ant
brew install apktool
brew install autoconf
brew install autojump
brew install automake
brew install awscli
brew install axel
brew install bash
brew install bash-completion
brew install bash-completion2
brew install bash-completion@2
brew install bfg
brew install binutils
brew install binwalk
brew install boost
brew install boot2docker
brew install brew-brew cask install-completion
brew install cairo
brew install calc
brew install chromedriver
brew install cifer
brew install cmake
brew install colordiff
brew install coreutils
brew install cowsay
brew install cryptopp
brew install cscope
brew install ctags
brew install curl
brew install dark-mode
brew install dash
brew install dex2jar
brew install direnv
brew install dns2tcp
brew install docker
brew install docker-compose
brew install docker-machine
brew install dockutil
brew install doxygen
brew install emacs
brew install ethereum
brew install faac
brew install fcrackzip
brew install fdk-aac
brew install ffmpeg
brew install fftw
brew install figlet
brew install findutils
brew install fish
brew install fontconfig
brew install foremost
brew install freetype
brew install gcc
brew install gdbm
brew install gdk-pixbuf
brew install gettext
brew install giflib
brew install git
brew install git-flow
brew install glib
brew install gmp
brew install gnupg
brew install gnupg21
brew install gnupg@2.1
brew install gnutls
brew install go
brew install gobject-introspection
brew install gradle
brew install graphicsmagick
brew install graphite2
brew install harfbuzz
brew install hashpump
brew install heroku
brew install highlight
brew install htop
brew install hub
brew install hugo
brew install hydra
brew install icoutils
brew install icu4c
brew install imagemagick
brew install ios-sim
brew install isl
brew install jasper
brew install jemalloc
brew install john
brew install jpeg
brew install knock
brew install lame
brew install libassuan
brew install libav
brew install libcroco
brew install libdnet
brew install libevent
brew install libexif
brew install libffi
brew install libgcrypt
brew install libgpg-error
brew install libgsf
brew install libidn2
brew install libksba
brew install libmemcached
brew install libmpc
brew install libogg
brew install libpng
brew install librsvg
brew install libtasn1
brew install libtermkey
brew install libtiff
brew install libtool
brew install libunistring
brew install libusb
brew install libusb-compat
brew install libuv
brew install libvorbis
brew install libvpx
brew install libvterm
brew install libxml2
brew install libyaml
brew install little-cms2
brew install lolcat
brew install lua
brew install luajit
brew install mas
brew install maven
brew install memcached
brew install mongodb
brew install mono
brew install moreutils
brew install mpfr
brew install msgpack
brew install mtr
brew install mysql
brew install neovim
brew install netpbm
brew install nettle
brew install ninja
brew install nmap
brew install node
brew install npth
brew install ntfs-3g
brew install openjpeg
brew install openssl
brew install openssl-osx-ca
brew install openssl@1.1
brew install optipng
brew install opus
brew install orc
brew install ossp-uuid
brew install p11-kit
brew install p7zip
brew install packer
brew install pandoc
brew install pango
brew install parity
brew install pcre
brew install pcre2
brew install perl
brew install pinentry
brew install pixman
brew install pkg-config
brew install pngcheck
brew install poppler
brew install postgresql
brew install py2cairo
brew install pyenv
brew install pygobject3
brew install python
brew install python3
brew install rbenv
brew install rcm
brew install readline
brew install reattach-to-user-namespace
brew install redis
brew install ruby
brew install ruby-build
brew install shared-mime-info
brew install shellcheck
brew install siege
brew install socat
brew install solidity
brew install sqlite
brew install sqlmap
brew install ssdeep
brew install ssh-askpass
brew install swagger-codegen
brew install swiftlint
brew install tcpflow
brew install tcpreplay
brew install terminal-notifier
brew install terraform
brew install the_silver_searcher
brew install tmux
brew install tomcat
brew install trash
brew install tree
brew install ucspi-tcp
brew install unar
brew install unibilium
brew install vim
brew install vips
brew install watch
brew install webp
brew install wget
brew install x264
brew install xvid
brew install xz
brew install yarn
brew install youtube-dl
brew install zsh

# Add softwares
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
brew cask install colorpicker
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
brew cask install java
brew cask install java7
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
brew cask install visual-studio-code
brew cask install vlc
brew cask install webpquicklook
brew cask install webstorm
brew cask install whiskey
brew cask install xmind
brew cask install xquartz
brew cask install xscope
brew cask install xtrafinder

# Remove outdated versions
brew cleanup