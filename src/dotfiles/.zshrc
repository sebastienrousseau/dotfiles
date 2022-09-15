# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🆂🅷🅴🅻🅻
# if [ "$TMUX" = "" ]; then tmux; fi

## 🅴🆇🅿🅾🆁🆃🆂
USER_LANGUAGE="en_GB.UTF-8" # Set the default language.
export DOTFILES_VERSION='0.2.450' # DotFiles v0.2.450.
export DOTFILES=$HOME/.dotfiles # Path to the dotfiles directory.
export LANG=${USER_LANGUAGE} # Set the default language.
export LANGUAGE=${USER_LANGUAGE} # Set the default language.
export LC_ALL=${USER_LANGUAGE} # Set the default language.
export TERM=xterm-256color # Use 256 color terminal.
export USER=$(whoami) # Set USER variable.
export ZSH_HOME=$DOTFILES/zsh # Path to the zsh directory.

## 🆂🅾🆄🆁🅲🅴🆂
source $ZSH_HOME/aliases.zsh # Load aliases.
source $ZSH_HOME/configurations.zsh # Load configurations.
source $ZSH_HOME/exit.zsh # Load exit.
source $ZSH_HOME/functions.zsh # Load functions.
source $ZSH_HOME/history.zsh # Load history.
source $ZSH_HOME/plugins/*/[^.#]*.zsh # Load plugins.
