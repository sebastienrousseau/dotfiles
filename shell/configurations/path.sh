#! /bin/bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Path configuration.

## 🅿🅰🆃🅷🆂

### Add 'PATH' entries.
  export PATH=/usr/local/bin:"$PATH" # Add /usr/local/bin to the path
  export PATH=/usr/local/sbin:"$PATH" # Add /usr/local/sbin to the path
  export PATH=/usr/bin:"$PATH" # Add /usr/bin to the path
  export PATH=/bin:"$PATH" # Add /bin to the path
  export PATH=/usr/sbin:"$PATH" # Add /usr/sbin to the path
  export PATH=/sbin:"$PATH" # Add /sbin to the path
  export PATH="$HOME"/.cargo/bin:"$PATH" # Add ~/.cargo/bin to the path
  export PATH="$HOME"/.yarn/bin:"$PATH" # Add ~/.yarn/bin to the path
  export PATH="$HOME"/go/bin:"$PATH" # Add ~/go/bin to the path

# Set ARCHFLAGS
ARCHFLAGS="-arch arm64"
export ARCHFLAGS

### Add 'PATH' entries.
if [[ "$OSTYPE" == "darwin"* ]]; then

  ### Uniquify 'PATH' entries.
  typeset -U PATH

  export PATH=/opt/homebrew/bin:"$PATH" # Homebrew binaries
  export PATH=/opt/homebrew/sbin:"$PATH" # Homebrew binaries

  # Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/share/doc/homebrew/Analytics.md
  export HOMEBREW_NO_ANALYTICS=1

  # set HOMEBREW_CASK_OPTS
  HOMEBREW_CASK_OPTS="--appdir=/Applications"
  export HOMEBREW_CASK_OPTS

fi

# set HOSTNAME
HOSTNAME=$(hostname -f)
export HOSTNAME

# set INPUTRC (so that .inputrc is respected)
INPUTRC=~/.inputrc
export INPUTRC

# Set JAVA_HOME
if [[ "$OSTYPE" == "darwin"* ]]; then
  JAVA_HOME="$(brew --prefix)/Cellar/openjdk/18.0.1/libexec"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
fi
export JAVA_HOME

# Set JRE_HOME
export JRE_HOME="${JAVA_HOME}"/jre

# set JENV_HOME
_JENV_HOME="$HOME/.jenv"

if [ -d "$_JENV_HOME" ]
then
  export JENV_HOME="$_JENV_HOME"
  export PATH="$JENV_HOME/bin:$PATH"
  eval "$(jenv init -)"
fi

PNPM_HOME="$HOME"/Library/pnpm
export PNPM_HOME

# Set SSL_CERT_FILE
# SSL_CERT_FILE=~/cacert.pem
# export SSL_CERT_FILE
