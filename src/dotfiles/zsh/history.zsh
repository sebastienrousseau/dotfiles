#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#                                                                           
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# History options
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

## History wrapper
function dotfiles_history {
  local clear list
  zparseopts -E c=clear l=list

  if [[ -n "$clear" ]]; then
    # if -c provided, clobber the history file
    echo -n >| "$HISTFILE"
    echo >&2 History file deleted. Reload the session to see its effects.
  elif [[ -n "$list" ]]; then
    # if -l provided, run as if calling `fc' directly
    builtin fc "$@"
  else
    # unless a number is provided, show all history events (starting from 1)
    [[ ${@[-1]-} = *[0-9]* ]] && builtin fc -l "$@" || builtin fc -l "$@" 1
  fi
}

# Timestamp format
case ${HIST_STAMPS-} in
  "mm/dd/yyyy") alias history='dotfiles_history -f' ;;
  "dd.mm.yyyy") alias history='dotfiles_history -E' ;;
  "yyyy-mm-dd") alias history='dotfiles_history -i' ;;
  "") alias history='dotfiles_history' ;;
  *) alias history="dotfiles_history -t '$HIST_STAMPS'" ;;
esac

# Command history configuration
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"

# Number of histories saved in memory
export HISTSIZE=50000 

# Number of histories saved in history file
export SAVEHIST=10000

# History command configuration
setopt always_to_end            # Move cursor to the end of a completed word.
setopt append_history           # Sessions will append their history list to the history file, rather than replace it. 
setopt auto_cd                  # cd to a directory if it's given without a command.
setopt auto_list                # Automatically list choices on ambiguous completion.
setopt auto_menu                # Show completion menu on a successive tab press.
setopt auto_param_keys          # Automatically complements parentheses
setopt auto_param_slash         # If completed parameter is a directory, add a trailing slash.
setopt auto_pushd               # Automatically push when cd
setopt auto_resume              # Resume if you execute the same command name as the suspended process
setopt bang_hist                # Perform textual history expansion
setopt complete_in_word         # Complete from both ends of a word.
setopt correct                  # Enable command correction prompts
setopt extended_history         # Save each command’s beginning timestamp (in seconds since the epoch) and the duration (in seconds) to the history file. 
setopt hist_beep                # Beep in ZLE when a widget attempts to access a history entry which isn’t there.
setopt hist_expire_dups_first   # Cause the oldest history event that has a duplicate to be lost before losing a unique event from the list.
setopt hist_ignore_space        # Remove command lines from the history list when the first character on the line is a space, or when one of the expanded aliases contains a leading space.
setopt hist_no_store            # Remove the history (fc -l) command from the history list when invoked.
setopt hist_reduce_blanks       # Remove superfluous blanks from each command line being added to the history list.
setopt hist_save_no_dups        # When writing out the history file, older commands that duplicate newer ones are omitted.
setopt hist_verify              # Whenever the user enters a line with history expansion, don’t execute the line directly; instead, perform history expansion and reload the line into the editing buffer.
setopt list_packed              # Display with complementary candidates packed
setopt list_types               # Mark the file type in the completion candidate list
setopt pushd_ignore_dups        # Don’t push multiple copies of the same directory onto the directory stack.
setopt share_history            # Imports new commands from the history file, and also causes the typed commands to be appended to the history file
