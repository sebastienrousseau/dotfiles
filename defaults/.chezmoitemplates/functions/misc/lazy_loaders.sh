# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Lazy Loaders for Heavy Tools

# NVM (Node Version Manager)
# Lazy load nvm only when nvm, node, npm, or yarn is called
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  lazy_nvm() {
    # The trigger names are ALIASES, not functions: `unset -f` alone
    # leaves them in place, so every later `node`/`npm` call routes
    # back through this loader and re-sources nvm.sh. Drop the aliases
    # first so the shell resolves the real functions nvm.sh defines.
    unalias nvm node npm yarn npx 2>/dev/null || true
    unset -f nvm node npm yarn npx
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
    if [[ -s "$NVM_DIR/bash_completion" ]]; then
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
    # `unalias` before anything else: `rbenv` here is an alias, and the
    # command substitution below is parsed at runtime with alias
    # expansion on (every interactive shell), so `$(rbenv init -)`
    # re-entered this function and forked without bound.
    unalias rbenv ruby gem bundle 2>/dev/null || true
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
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  lazy_sdk() {
    # Same alias-vs-function trap as lazy_nvm above.
    unalias sdk java gradle mvn kotlin 2>/dev/null || true
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
