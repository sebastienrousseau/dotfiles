#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets history options for the current shell.
# License: MIT
# Script: history.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# Exit immediately if any command fails
set -o errexit

# Exit if any undefined variables are used
set -o nounset

## History wrapper
function dotfiles_history {
  local clear list
  zparseopts -E c=clear l=list

  if [[ -n "${clear:-}" ]]; then
    # if -c provided, clobber the history file
    echo -n >|"${HISTFILE:-}"
    echo >&2 "History file deleted. Reload the session to see its effects."
  elif [[ -n "${list:-}" ]]; then
    # if -l provided, run as if calling `fc' directly
    builtin fc "$@"
  else
    # unless a number is provided, show all history events (starting from 1)
    if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
      builtin fc "$@"
    else
      builtin fc -l 1
    fi
  fi
}

# Timestamp format
case "${HIST_STAMPS:-}" in
"mm/dd/yyyy") alias history='dotfiles_history -f' ;;
"dd.mm.yyyy") alias history='dotfiles_history -E' ;;
"yyyy-mm-dd") alias history='dotfiles_history -i' ;;
"") alias history='dotfiles_history' ;;
*) alias history='dotfiles_history -t ${HIST_STAMPS}' ;;
esac

export HISTFILE="${HOME}/.zsh_history" # History file
export HISTCONTROL="ignoreboth"        # Ignore duplicate commands and commands that start with a space
export HISTSIZE="10000"                # Number of commands to save in memory
export SAVEHIST="1000"                 # Number of commands to save on disk

if [[ -n "${ZSH_VERSION:-}" ]]; then
  # echo "Running shell is zsh"
  # Specifying some history options
  setopt always_to_end          # Move cursor to the end of a completed word.
  setopt append_history         # Sessions will append their history list to the history file, rather than replace it.
  setopt auto_cd                # cd to a directory if it's given without a command.
  setopt auto_list              # Automatically list choices on ambiguous completion.
  setopt auto_menu              # Show completion menu on a successive tab press.
  setopt auto_param_keys        # Automatically complements parentheses
  setopt auto_param_slash       # If completed parameter is a directory, add a trailing slash.
  setopt auto_pushd             # Automatically push when cd
  setopt auto_resume            # Resume if you execute the same command name as the suspended process
  setopt bang_hist              # Perform textual history expansion
  setopt complete_in_word       # Complete from both ends of a word.
  setopt correct                # Enable command correction prompts
  setopt extended_history       # Save each command’s beginning timestamp (in seconds since the epoch) and the duration (in seconds) to the history file.
  setopt hist_beep              # Beep in ZLE when a widget attempts to access a history entry which isn’t there.
  setopt hist_expire_dups_first # Cause the oldest history event that has a duplicate to be lost before losing a unique event from the list.
  setopt hist_ignore_space      # Remove command lines from the history list when the first character on the line is a space, or when one of the expanded aliases contains a leading space.
  setopt hist_no_store          # Remove the history (fc -l) command from the history list when invoked.
  setopt hist_reduce_blanks     # Remove superfluous blanks from each command line being added to the history list.
  setopt hist_save_no_dups      # When writing out the history file, older commands that duplicate newer ones are omitted.
  setopt hist_verify            # Whenever the user enters a line with history expansion, don’t execute the line directly; instead, perform history expansion and reload the line into the editing buffer.
  setopt list_packed            # Display with complementary candidates packed
  setopt list_types             # Mark the file type in the completion candidate list
  setopt pushd_ignore_dups      # Don’t push multiple copies of the same directory onto the directory stack.
  setopt share_history          # Imports new commands from the history file, and also causes the typed commands to be appended to the history file
  setopt transient_rprompt      # Display the right prompt only when the cursor is on the rightmost column.

elif [[ -n "${BASH_VERSION}" ]]; then
  # echo "Running shell is bash"
  # Shopt settings
  shopt -s autocd                  # autocd - automatically cd to a directory when it is the only argument to a command
  shopt -s cdspell                 # cdspell - spell check the path when changing directories.
  shopt -s checkhash               # checkhash - check hash table for commands before running them.
  shopt -s checkjobs               # checkjobs - check for stopped jobs after each command and report them to the user.
  shopt -s checkwinsize            # checkwinsize - check the window size after each command and, if necessary, update the values of LINES and COLUMNS.
  shopt -s cmdhist                 # cmdhist - save multi-line commands as one entry in history.
  shopt -s dirspell                # dirspell - spell check the path when changing directories.
  shopt -s dotglob                 # dotglob - include dotfiles in globbing.
  shopt -s extglob                 # extglob - extended globbing.
  shopt -s globstar                # globstar - allow ** to match multiple directories.
  shopt -s histappend              # histappend - append to the history file, don't overwrite it.
  shopt -s histverify              # histverify - verify commands from history before executing them.
  shopt -s hostcomplete            # hostcomplete - complete hostnames when using the ssh command.
  shopt -s lithist                 # lithist - save multi-line commands as one entry in history.
  shopt -s huponexit               # huponexit - send SIGHUP to jobs when the shell exits.
  shopt -s no_empty_cmd_completion # no_empty_cmd_completion - don't complete empty commands.
  shopt -s nocaseglob              # nocaseglob - case insensitive globbing.
  shopt -s nocasematch             # nocasematch - case insensitive matching.
  shopt -s nullglob                # nullglob - if no matches are found, the pattern expands to nothing.
  shopt -s progcomp                # progcomp - programmable completion.
  shopt -s promptvars              # promptvars - allow prompt strings to contain shell variables.
  shopt -s sourcepath              # sourcepath - search the PATH for the directory containing a sourced script before using the current directory.

else
  echo "Unsupported shell: ${SHELL}"
  exit 1
fi
