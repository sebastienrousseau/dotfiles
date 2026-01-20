# shellcheck shell=bash
# Lazy Loaders for Heavy Tools

# NVM (Node Version Manager)
# Lazy load nvm only when nvm, node, npm, or yarn is called
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  lazy_nvm() {
    unset -f nvm node npm yarn npx
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    if [ -s "$NVM_DIR/bash_completion" ]; then
      \. "$NVM_DIR/bash_completion"
    fi
    # Execute the command that triggered the load
    "$@"
  }

  alias nvm="lazy_nvm nvm"
  alias node="lazy_nvm node"
  alias npm="lazy_nvm npm"
  alias yarn="lazy_nvm yarn"
  alias npx="lazy_nvm npx"
fi

# RBENV (Ruby Version Manager)
if command -v rbenv >/dev/null; then
  lazy_rbenv() {
    unset -f rbenv ruby gem bundle
    eval "$(rbenv init -)"
    "$@"
  }
  
  alias rbenv="lazy_rbenv rbenv"
  alias ruby="lazy_rbenv ruby"
  alias gem="lazy_rbenv gem"
  alias bundle="lazy_rbenv bundle"
fi

# SDKMAN (Java/Groovy/Scala Version Manager)
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  lazy_sdk() {
    unset -f sdk java gradle mvn kotlin
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    "$@"
  }
  
  alias sdk="lazy_sdk sdk"
  alias java="lazy_sdk java"
  alias gradle="lazy_sdk gradle"
  alias mvn="lazy_sdk mvn"
  alias kotlin="lazy_sdk kotlin"
fi
