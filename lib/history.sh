#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: history.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script to manage shell history configuration and display
# Website: https://dotfiles.io
# License: MIT
################################################################################

## 🅷🅸🆂🆃🅾🆁🆈

# Function: dotfiles_history
#
# Description:
#   Manages shell history configuration and display.
#
# Options:
#   -c    Clears the history file and removes duplicates.
#   -l    Lists history events. Accepts arguments similar to `fc` command.
#
# Returns:
#   0 on success, non-zero on failure
#
# Further Reading:
#   Zsh History Documentation: https://www.zsh.org/mla/users/2007/msg00366.html
#   Bash History Builtins Documentation: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#Bash-Builtins

dotfiles_history() {
  local clear_flag="" list_flag=""
  local verbose=${DOTFILES_VERBOSE:-0}
  local ret=0

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    zparseopts -E c=clear_flag l=list_flag || ret=$?
  else
    clear_flag=$( [[ "$1" == "-c" ]] && echo "1" || echo "" )
    list_flag=$( [[ "$1" == "-l" ]] && echo "1" || echo "" )
  fi

  if (( ret != 0 )); then
    echo "Error parsing options" >&2
    return ${ret}
  fi

  if [[ -n ${clear_flag} ]]; then
    fc -W
    fc -R
    echo "History file deleted and duplicates removed. Reload the session to see its effects." >&2
    return 0
  elif [[ -n ${list_flag} ]] || [[ $# -ne 0 ]]; then
    local fc_output
    if ! fc_output=$(builtin fc "$@" 2>/dev/null); then
      echo "Error retrieving history" >&2
      return 1
    fi

    # Use simpler color handling that works across terminals
    if command -v tput >/dev/null 2>&1; then
      printf '%s\n' "$(tput setaf 2)${fc_output}$(tput sgr0)" || {
        # Fallback if color fails
        printf '%s\n' "${fc_output}"
      }
    else
      printf '%s\n' "${fc_output}"
    fi
  else
    fc -W
    local fc_output
    if ! fc_output=$(builtin fc -li 1 2>/dev/null); then
      echo "Error retrieving history" >&2
      return 1
    fi

    if command -v tput >/dev/null 2>&1; then
      printf '%s\n' "$(tput setaf 2)${fc_output}$(tput sgr0)" || {
        # Fallback if color fails
        printf '%s\n' "${fc_output}"
      }
    else
      printf '%s\n' "${fc_output}"
    fi
  fi

  return 0
}

# Function: apply_shell_configurations
#
# Description:
#   Applies shell-specific history configurations
#
# Returns:
#   0 on success, 1 on unsupported shell
#
# Further Reading:
#   Zsh Options Documentation: https://zsh.sourceforge.io/Doc/Release/Options.html
#   Bash shopt Documentation: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html

apply_shell_configurations() {
  local verbose=${DOTFILES_VERBOSE:-0}

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt hist_ignore_space hist_no_store hist_reduce_blanks hist_expire_dups_first hist_save_no_dups append_history
    export HISTFILE="${HOME}/.zsh_history"
    export HISTSIZE="10000"
    export SAVEHIST="1000"
    (( verbose )) && echo "Applied Zsh history configurations"
  elif [[ -n "${BASH_VERSION}" ]]; then
    export HISTFILE="${HOME}/.bash_history"
    export HISTCONTROL="ignoreboth"
    export HISTSIZE="10000"
    shopt -s histappend histverify nocaseglob dotglob
    (( verbose )) && echo "Applied Bash history configurations"
  else
    echo "Warning: Unsupported shell: ${SHELL}" >&2
    return 1
  fi

  return 0
}

# Function: configure_history
#
# Description:
#   Configures shell history settings and aliases.
#
# Returns:
#   0 on success
#
# Further Reading:
#   Alias Documentation: https://www.gnu.org/software/bash/manual/html_node/Aliases.html

configure_history() {
  local verbose=${DOTFILES_VERBOSE:-0}

  # Write current history to file
  fc -W

  # Set up aliases
  alias h='dotfiles_history'
  alias history='dotfiles_history'

  (( verbose )) && echo "Configured history aliases"
  return 0
}

# Main Execution
# ---------------------------------------------------------
# Apply shell-specific settings first
apply_shell_configurations || {
  # Don't exit, just warn - this allows the script to be sourced in any shell
  echo "Warning: Could not apply shell-specific history configurations" >&2
}

# Then configure history commands
configure_history
