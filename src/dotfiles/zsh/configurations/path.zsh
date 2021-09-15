#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#                                                                           
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Sections:
#
#   1.0 Setting PATH environments.
#      1.1 Prepend $PATH without duplicates.
#      1.2 Construct $PATH. 
#      1.3 Custom exports. 
#      
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

#   ----------------------------------------------------------------------------
#  	1.0 Setting PATH environments.
#   ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Prepend $PATH without duplicates.
##  ----------------------------------------------------------------------------

# prependpath: Prepend $PATH without duplicates
function prependpath() {
    if ! $( echo "$PATH" | tr ":" "\n" | grep -qx "$1" ) ; then
        PATH="$1:$PATH"
    fi
}



##  ----------------------------------------------------------------------------
##  1.2 Construct $PATH.
##  - Default Paths,
##  - Custom bin folder for Homebrew, Node, OpenJDK, Ruby, Python, CoreUtils.
##  ----------------------------------------------------------------------------

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Add Homebrew to PATH
[ -d /usr/local/bin ] && prependpath "/usr/local/bin"

# Add Homebrew to PATH
[ -d /usr/local/sbin ] && prependpath "/usr/local/sbin"

# Add NPM to PATH
[ -d /usr/local/bin/npm ] && prependpath "/usr/local/bin/npm"

# Add Node to PATH
[ -d /usr/local/bin/node ] && prependpath "/usr/local/bin/node"

# Add OpenJDK to PATH
[ -d /usr/local/opt/openjdk/bin ] && prependpath "/opt/openjdk/bin"

# Add Ruby to PATH
[ -d /usr/local/opt/ruby/bin ] && prependpath "/usr/local/opt/ruby/bin"

# Add Python to PATH
[ -d /usr/local//opt/python/libexec/bin ] && prependpath "/opt/python/libexec/bin"

# Add CoreUtils to PATH
[ -d /usr/local/opt/coreutils/libexec/gnubin ] && prependpath "/usr/local/opt/coreutils/libexec/gnubin"

export PATH

# Enable Heroku
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

##  ----------------------------------------------------------------------------
##  1.3 Custom exports.
##  ----------------------------------------------------------------------------

# Set ANT_HOME
ANT_HOME="$(brew --prefix)/Cellar/ant/1.10.11/libexec/"
export ANT_HOME

# Set MAVEN_HOME
MAVEN_HOME="$(brew --prefix)/Cellar/maven/3.8.2/libexec"
export MAVEN_HOME

# Set M2
M2=$MAVEN_HOME/bin
export M2

# Set ARCHFLAGS
ARCHFLAGS="-arch x86_64"
export ARCHFLAGS

# GO
GOROOT="$(brew --prefix)/opt/go/libexec"
export GOROOT

GOPATH=$HOME/.go
export GOPATH

GOBIN=$GOPATH/bin
export GOBIN

PATH=$PATH:$GOPATH
export PATH

PATH=$PATH:$GOROOT/bin
export PATH

export GO111MODULE=off

# set HOMEBREW_CASK_OPTS
HOMEBREW_CASK_OPTS="--appdir=/Applications"
export HOMEBREW_CASK_OPTS

# set HOSTNAME
HOSTNAME=$(hostname -f)
export HOSTNAME

# set INPUTRC (so that .inputrc is respected)
INPUTRC=~/.inputrc
export INPUTRC

# set JENV_HOME
_JENV_HOME="$HOME/.jenv"

if [ -d "$_JENV_HOME" ]
then
  export JENV_HOME=$_JENV_HOME
  export PATH="$JENV_HOME/bin:$PATH"
  eval "$(jenv init -)"
fi

# Set language flags
LANG=en_GB.UTF-8
export LANG 

# Set LIBCURL_CFLAGS
LIBCURL_CFLAGS=-L$(brew --prefix)/opt/curl/lib
export LIBCURL_CFLAGS

# Set LIBCURL_LIBS
LIBCURL_LIBS=-I$(brew --prefix)/opt/curl/include
export LIBCURL_LIBS

# Set MAVEN_OPTS
MAVEN_OPTS="-Xms512m -Xmx512m"
export MAVEN_OPTS

# Set NVM_DIR
NVM_DIR="$HOME/.nvm"
export NVM_DIR
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

# Set SSL_CERT_FILE
SSL_CERT_FILE=~/cacert.pem
export SSL_CERT_FILE

# Set ZSH_CURRENT_USER
ZSH_CURRENT_USER=$(whoami)
export ZSH_CURRENT_USER

# Set LDFLAGS
export LDFLAGS="-L$(brew --prefix)/opt/ruby/lib"
export CPPFLAGS="-I$(brew --prefix)/opt/ruby/include"
export PKG_CONFIG_PATH="$(brew --prefix)/opt/ruby/lib/pkgconfig"

# NodeJS, NPM exports
export PATH="./$HOME/.npm-packages/bin:$PATH"
export NPM_PACKAGES="$HOME/.npm-packages"
export NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"
export PATH="$NPM_PACKAGES/bin:$PATH"

# Set Heroku
export FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"

# Set Perl
eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib=$HOME/perl5)"

# Set travis
[ -f $HOME/.travis/travis.sh ] && source $HOME/.travis/travis.sh

# Set Ruby
export PATH="$(brew --prefix)/opt/ruby/bin:$PATH"
export GEM_HOME="$(brew --prefix)/Cellar/ruby/3.0.2/lib/ruby/gems/3.0.0/"
export GEM_PATH="$(brew --prefix)/Cellar/ruby/3.0.2/lib/ruby/gems/3.0.0/"
export PATH="$(brew --prefix)/Cellar/ruby/3.0.2/lib/ruby/gems/3.0.0/bin:$PATH"

# Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/share/doc/homebrew/Analytics.md
export HOMEBREW_NO_ANALYTICS=1
