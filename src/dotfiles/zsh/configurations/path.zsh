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
# Environment Variables
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

# Setting PATH environments
export PATH="/usr/local/opt/openjdk/bin:$PATH"

# Set ANT_HOME
ANT_HOME="$(brew --prefix)/Cellar/ant/1.10.10/libexec/"
export ANT_HOME

# Set MAVEN_HOME
MAVEN_HOME="$(brew --prefix)/Cellar/maven/3.8.1/libexec"
export MAVEN_HOME

# Set M2
M2=$MAVEN_HOME/bin
export M2

# Set ARCHFLAGS
ARCHFLAGS="-arch x86_64"
export ARCHFLAGS

# GO
GOROOT=$(brew --prefix)/opt/go/libexec
export GOROOT
export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin

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

ANDROID_HOME="$HOME/Library/Android/sdk/"
export ANDROID_HOME

PATH=$ANDROID_HOME/tools:$PATH
export PATH

PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH

PATH="$(brew --prefix)/opt/python/libexec/bin:$PATH"
export PATH

PATH="$(brew --prefix)/sbin:$PATH"
export PATH

# GH_TOKEN="YOUR GH_TOKEN"
# export GH_TOKEN

# AWS_ACCESS_KEY_ID=<Your requested AWS access ID>
# export AWS_ACCESS_KEY_ID

# AWS_SECRET_ACCESS_KEY=<Your requested secret access key>
# export AWS_SECRET_ACCESS_KEY

eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib=$HOME/perl5)"

# added by travis gem
[ -f $HOME/.travis/travis.sh ] && source $HOME/.travis/travis.sh

# Add RVM to PATH for scripting. 
export PATH="$PATH:$HOME/.rvm/bin"