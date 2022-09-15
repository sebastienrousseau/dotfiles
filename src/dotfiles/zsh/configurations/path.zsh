#!/usr/bin/env zsh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🅿🅰🆃🅷🆂

### Uniquify 'PATH' entries.
typeset -U PATH

### Add 'PATH' entries.
if [[ -d /opt/homebrew/bin ]]; then
  export PATH=/opt/homebrew/bin:$PATH # Homebrew binaries
  export PATH=/opt/homebrew/sbin:$PATH # Homebrew binaries
fi
export PATH=/bin:$PATH # Add /bin to the path
export PATH=/sbin:$PATH # Add /sbin to the path
export PATH=/usr/bin:$PATH # Add /usr/bin to the path
export PATH=/usr/local/bin:$PATH # Add /usr/local/bin to the path
export PATH=/usr/local/sbin:$PATH # Add /usr/local/sbin to the path
export PATH=/usr/sbin:$PATH # Add /usr/sbin to the path
export PATH=$HOME/.cargo/bin:$PATH # Add ~/.cargo/bin to the path
export PATH=$HOME/.yarn/bin:$PATH # Add ~/.yarn/bin to the path
export PATH=$HOME/go/bin:$PATH # Add ~/go/bin to the path


# Set ARCHFLAGS
ARCHFLAGS="-arch arm64"
export ARCHFLAGS

# GO
# GOROOT="$(brew --prefix)/opt/go/libexec"
# export GOROOT

# GOPATH=$HOME/.go
# export GOPATH

# GOBIN=$GOPATH/bin
# export GOBIN

# PATH=$PATH:$GOPATH
# export PATH

# PATH=$PATH:$GOROOT/bin
# export PATH

# export GO111MODULE=off

# set openjdk
# export PATH="$(brew --prefix)/opt/openjdk/bin:$PATH"
# export PATH="$(brew --prefix)/opt/openssl@3/bin:$PATH"

# export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
#export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"

# set HOMEBREW_CASK_OPTS
HOMEBREW_CASK_OPTS="--appdir=/Applications"
export HOMEBREW_CASK_OPTS

# set HOSTNAME
HOSTNAME=$(hostname -f)
export HOSTNAME

# set INPUTRC (so that .inputrc is respected)
INPUTRC=~/.inputrc
export INPUTRC

# Set JAVA_HOME
# For zsh shell, export $JAVA_HOME at ~/.zshenv or ~/.zshrc.
JAVA_HOME="$(brew --prefix)/Cellar/openjdk/18.0.1/libexec"
export JAVA_HOME

# Set JRE_HOME
export JRE_HOME=${JAVA_HOME}/jre

# set JENV_HOME
_JENV_HOME="$HOME/.jenv"

if [ -d "$_JENV_HOME" ]
then
  export JENV_HOME=$_JENV_HOME
  export PATH="$JENV_HOME/bin:$PATH"
  eval "$(jenv init -)"
fi

# set PERL
# eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib=$HOME/perl5)"

# Set language flags
# LANG=en_GB.UTF-8
# export LANG

# Set LIBCURL_CFLAGS
LIBCURL_CFLAGS=-L$(brew --prefix)/opt/curl/lib
export LIBCURL_CFLAGS

# Set LIBCURL_LIBS
LIBCURL_LIBS=-I$(brew --prefix)/opt/curl/include
export LIBCURL_LIBS

# Set MAVEN_OPTS
# MAVEN_OPTS="-Xms512m -Xmx512m"
# export MAVEN_OPTS

# Set SSL_CERT_FILE
SSL_CERT_FILE=~/cacert.pem
export SSL_CERT_FILE

# Set ZSH_CURRENT_USER
# ZSH_CURRENT_USER=$(whoami)
# export ZSH_CURRENT_USER

# Set LDFLAGS
# export LDFLAGS="-L$(brew --prefix)/opt/ruby/lib"
# export CPPFLAGS="-I$(brew --prefix)/opt/ruby/include"
# export PKG_CONFIG_PATH="$(brew --prefix)/opt/ruby/lib/pkgconfig"

# Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/share/doc/homebrew/Analytics.md
export HOMEBREW_NO_ANALYTICS=1
