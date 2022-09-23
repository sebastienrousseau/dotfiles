#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂
USER_LANGUAGE="en_GB.UTF-8" # Set the default language.
USER=$(whoami) # Set USER variable.

## 🅴🆇🅿🅾🆁🆃🆂
export DOTFILES_VERSION='0.2.450' # DotFiles version.
export DOTFILES=$HOME/.dotfiles/shell # Path to the dotfiles directory.
export LANG=${USER_LANGUAGE} # Set the default language.
export LANGUAGE=${USER_LANGUAGE} # Set the default language.
export LC_ALL=${USER_LANGUAGE} # Set the default language.
export TERM=xterm-256color # Use 256 color terminal.
export USER # Set USER variable.

## 🆂🅾🆄🆁🅲🅴🆂
# shellcheck source=/dev/null
source "$DOTFILES"/aliases.sh # Load aliases.

# shellcheck source=/dev/null
source "$DOTFILES"/configurations.sh # Load configurations.

# shellcheck source=/dev/null
source "$DOTFILES"/exit.sh # Load exit.

# shellcheck source=/dev/null
source "$DOTFILES"/functions.sh # Load functions.

# shellcheck source=/dev/null
source "$DOTFILES"/history.sh # Load history.

# shellcheck source=/dev/null
source "$DOTFILES"/plugins/*/[^.#]*.sh # Load plugins.
