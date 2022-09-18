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
export DF_HOME=$DOTFILES/zsh # Path to the zsh directory.

## 🆂🅾🆄🆁🅲🅴🆂
source $DF_HOME/aliases.zsh # Load aliases.
source $DF_HOME/configurations.zsh # Load configurations.
source $DF_HOME/exit.zsh # Load exit.
source $DF_HOME/functions.zsh # Load functions.
source $DF_HOME/history.zsh # Load history.
source $DF_HOME/plugins/*/[^.#]*.zsh # Load plugins.
