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

dotfiles_history() {
  local clear_flag="" list_flag=""

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    zparseopts -E c=clear_flag l=list_flag || true
  else
    clear_flag=$( [[ "$1" == "-c" ]] && echo "1" || echo "" )
    list_flag=$( [[ "$1" == "-l" ]] && echo "1" || echo "" )
  fi

  if [[ -n ${clear_flag} ]]; then
    fc -W
    fc -R
    echo "History file deleted and duplicates removed. Reload the session to see its effects." >&2
  elif [[ -n ${list_flag} ]] || [[ $# -ne 0 ]]; then
    local fc_output
    fc_output=$(builtin fc "$@")
    printf '%s\n' "$(tput setaf 5)$(tput sgr0)$(tput setaf 2)$(echo "${fc_output//$'\e'/$(tput setaf 2)}" | sed -E "s/^([[:space:]]*[0-9]+)/$(tput setaf 2)\1$(tput sgr0)/")" || true
  else
    fc -W
    local fc_output
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

configure_history() {
  fc -W

  alias h='dotfiles_history'
  alias history='dotfiles_history'
}

# Apply shell-specific configurations
apply_shell_configurations() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt hist_ignore_space hist_no_store hist_reduce_blanks hist_expire_dups_first hist_save_no_dups append_history
    export HISTFILE="${HOME}/.zsh_history"
    export HISTSIZE="10000"
    export SAVEHIST="1000"
  elif [[ -n "${BASH_VERSION}" ]]; then
    export HISTFILE="${HOME}/.bash_history"
    export HISTCONTROL="ignoreboth"
    export HISTSIZE="10000"
    shopt -s histappend histverify nocaseglob dotglob
  else
    echo "Unsupported shell: ${SHELL}" >&2
    exit 1
  fi
}

# Main Execution
# ---------------------------------------------------------
configure_history
apply_shell_configurations
