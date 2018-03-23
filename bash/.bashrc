#!/bin/bash -l

#  ---------------------------------------------------------------------------
#
#  ______      _  ______ _ _           
#  |  _  \    | | |  ___(_) |          
#  | | | |___ | |_| |_   _| | ___  ___ 
#  | | | / _ \| __|  _| | | |/ _ \/ __|
#  | |/ / (_) | |_| |   | | |  __/\__ \
#  |___/ \___/ \__\_|   |_|_|\___||___/
#                                                                            
#  Description:  Add these lines to your .bashrc for aliases and functions
#
#  ---------------------------------------------------------------------------

# Don't enable any fancy or breaking features if the shell session is non-interactive
if [[ $- != *i* ]] ; then
        return
fi

# Source the .bash_aliases file.
if [[ -f ~/.bash_aliases ]] ; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/.bash_aliases"
fi

# Source the .bash_load_completion file.
if [[ -f ~/.bash_load_completion ]]; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/.bash_load_completion"
fi

# Source the .bash_functions file.
if [[ -f ~/.bash_functions ]]; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/.bash_functions"
fi

# Source the .bash_exit file.
if [[ -f ~/.bash_exit ]]; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/.bash_exit"
fi
