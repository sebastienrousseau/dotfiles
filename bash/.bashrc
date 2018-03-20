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
if [ -f ~/.bash_aliases ]; then
  source ~/.bash_aliases
fi

# Source the .bash_load_completion file.
if [ -f ~/.bash_load_completion ]; then
  source ~/.bash_load_completion
fi