#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂
USER_LANGUAGE="en_GB.UTF-8" # Set the default language.
USER=$(whoami) # Set USER variable.

## 🅴🆇🅿🅾🆁🆃🆂
export DF_HOME=$DOTFILES/dots # Path to the bash directory.
export DOTFILES_VERSION='0.2.450' # DotFiles v0.2.450.
export DOTFILES=$HOME/.dotfiles # Path to the dotfiles directory.
export LANG=${USER_LANGUAGE} # Set the default language.
export LANGUAGE=${USER_LANGUAGE} # Set the default language.
export LC_ALL=${USER_LANGUAGE} # Set the default language.
export TERM=xterm-256color # Use 256 color terminal.
export USER # Set USER variable.

## 🆂🅾🆄🆁🅲🅴🆂
# shellcheck source=/dev/null
source "$DF_HOME"/aliases.bash # Load aliases.

# shellcheck source=/dev/null
source "$DF_HOME"/configurations.bash # Load configurations.

# shellcheck source=/dev/null
source "$DF_HOME"/exit.bash # Load exit.

# shellcheck source=/dev/null
source "$DF_HOME"/functions.bash # Load functions.

# shellcheck source=/dev/null
source "$DF_HOME"/history.bash # Load history.

# shellcheck source=/dev/null
source "$DF_HOME"/plugins/*/[^.#]*.sh # Load plugins.
