#!/usr/bin/env bash

#  ---------------------------------------------------------------------------
#
#  ______      _  ______ _ _           
#  |  _  \    | | |  ___(_) |          
#  | | | |___ | |_| |_   _| | ___  ___ 
#  | | | / _ \| __|  _| | | |/ _ \/ __|
#  | |/ / (_) | |_| |   | | |  __/\__ \
#  |___/ \___/ \__\_|   |_|_|\___||___/
#                                                                            
#  Description: Install Packages with Homebrew for OS X
#
#  ---------------------------------------------------------------------------


#  ---------------------------------------------------------------------------
# Make sure we’re using the latest Homebrew.
#  ---------------------------------------------------------------------------
brew update


#  ---------------------------------------------------------------------------
# Upgrade any already-installed formulae.
#  ---------------------------------------------------------------------------
brew upgrade


#  ---------------------------------------------------------------------------
# Many of the binaries require Java so to avoid errors and warning Java 
# is being installed first
#  ---------------------------------------------------------------------------
brew cask install java
brew cask install java8 ## added to replace java7, line above installs java 9


#  ---------------------------------------------------------------------------
# Add binaries
#  ---------------------------------------------------------------------------
#brew install bash-completion@2 ## Further setup required. see .bash_completion file
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
brew install bfg
brew install binutils
brew install binwalk
brew install boost
brew install boot2docker # Moved here (from alphabetical order for cleaner install)
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


#  ---------------------------------------------------------------------------
# Remove outdated versions
#  ---------------------------------------------------------------------------
brew cleanup