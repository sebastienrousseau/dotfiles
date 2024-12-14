#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: history.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script to manage shell history configuration and display
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Function: dotfiles_history
#
# Description:
#   Manages shell history configuration and display.
#
# Options:
#   -c    Clears the history file and removes duplicates.
#   -l    Lists history events. Accepts arguments similar to `fc` command.
#
# Further Reading:
#   Zsh History Documentation: https://www.zsh.org/mla/users/2007/msg00366.html
#   Bash History Builtins Documentation: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#Bash-Builtins

function dotfiles_history {
  local clear_flag list_flag
  zparseopts -E c=clear_flag l=list_flag

  if [[ -n ${clear_flag} ]]; then
    # Clear the history file and remove duplicates
    fc -W
    fc -R
    echo "History file deleted and duplicates removed. Reload the session to see its effects." >&2
  elif [[ -n ${list_flag} ]] || [[ $# -ne 0 ]]; then
    # If -l flag is provided or arguments are passed, run as if calling `fc` directly
    fc_output=$(builtin fc "$@")
    printf '%s\n' "$(tput setaf 5)$(tput sgr0)$(tput setaf 2)$(echo "${fc_output//$'\e'/$(tput setaf 2)}" | sed -E "s/^([[:space:]]*[0-9]+)/$(tput setaf 2)\1$(tput sgr0)/")" || true
  else
    # Ensure the history file has no duplicates and show all history events starting from 1
    fc -W # Remove duplicates from the history file
    fc_output=$(builtin fc -li 1)
    printf '%s\n' "$(tput setaf 5)$(tput sgr0)$(tput setaf 2)$(echo "${fc_output//$'\e'/$(tput setaf 2)}" | sed -E "s/^([[:space:]]*[0-9]+)/$(tput setaf 2)\1$(tput sgr0)/")" || true
  fi
}

# Function: configure_history
#
# Description:
#   Configures shell history settings and aliases.
#
# Further Reading:
#   Zsh Options Documentation: https://zsh.sourceforge.io/Doc/Release/Options.html
#   Bash shopt Documentation: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html

function configure_history() {

  fc -W

  # Alias to list recent commands
  alias h='dotfiles_history'

  # Alias to view history
  alias history='dotfiles_history'

}

# Zsh Config
# ---------------------------------------------------------
# Explanation of Zsh options:
#   - hist_ignore_space: Removes command lines from the history list when the first character on the line is a space.
#   - hist_no_store: Removes the history command from the history list when invoked.
#   - hist_reduce_blanks: Removes superfluous blanks from each command line being added to the history list.

export HISTFILE="${HOME}/.zsh_history" # History file
export HISTCONTROL="ignoreboth"        # Ignore duplicate commands and commands that start with a space
export HISTSIZE="10000"                # Number of commands to save in memory
export SAVEHIST="1000"                 # Number of commands to save on disk

# Bash Config
# ---------------------------------------------------------
# Explanation of Bash shopts:
#   - histappend: Append to the history file, don't overwrite it.
#   - histverify: Verify commands from history before executing them.
#   - nocaseglob: Case insensitive globbing.

if [[ -n "${ZSH_VERSION:-}" ]]; then
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
