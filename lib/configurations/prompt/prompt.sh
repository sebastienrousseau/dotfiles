#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: prompt.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure shell prompts with Git integration
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Function: check_interactive_shell
#
# Description:
#   Checks if the current shell is interactive and exits early if not.
#
# Arguments:
#   None
#
# Returns:
#   0 if interactive, 1 otherwise (with early return)
#-----------------------------------------------------------------------------
check_interactive_shell() {
  if [[ $- != *i* ]]; then
    # Exit early for non-interactive shells
    return 1
  fi
  return 0
}

#-----------------------------------------------------------------------------
# Function: check_terminal_capabilities
#
# Description:
#   Checks if terminal has advanced capabilities for fancy prompts.
#
# Arguments:
#   None
#
# Returns:
#   0 if terminal supports fancy prompts, 1 otherwise
#-----------------------------------------------------------------------------
check_terminal_capabilities() {
  # Check if terminal supports 256 colors, is Alacritty, or is Kitty
  if [[ ${TERM} != *-256color* && ${TERM} != alacritty* && ${TERM} != *-kitty* ]]; then
    return 1
  fi
  return 0
}

#-----------------------------------------------------------------------------
# Function: define_colors
#
# Description:
#   Defines color codes for prompt formatting.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
define_colors() {
  # Color definitions for ANSI-compatible terminals
  tmux_purple='\[\033[38;5;55m\]'     # Purple (#2D1681)
  tmux_red='\[\033[38;5;196m\]'       # Red (#EB0000)
  tmux_blue='\[\033[38;5;33m\]'       # Blue (#007ACC)
  tmux_white='\[\033[38;5;15m\]'      # White (#FFFFFF)
  tmux_green='\[\033[38;5;46m\]'      # Green for clean git status
  tmux_yellow='\[\033[38;5;226m\]'    # Yellow for dirty git status
  reset='\[\033[0m\]'

  # Export colors so they're available to other functions
  export tmux_purple tmux_red tmux_blue tmux_white tmux_green tmux_yellow reset

  return 0
}

#-----------------------------------------------------------------------------
# Function: get_os_info
#
# Description:
#   Determines the OS type and returns an appropriate icon, name, and emoji.
#
# Arguments:
#   None
#
# Returns:
#   Sets OS_ICON, OS_NAME, and OS_EMOJI variables
#-----------------------------------------------------------------------------
get_os_info() {
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    OS_ICON=" "
    OS_NAME="macOS"
    OS_EMOJI="🍎"
  elif [[ "${OSTYPE}" == "linux"* ]]; then
    OS_ICON="🐧"
    OS_NAME="Linux"
    OS_EMOJI="🐧"
  elif [[ "${OSTYPE}" == "freebsd"* ]]; then
    OS_ICON="😈"
    OS_NAME="FreeBSD"
    OS_EMOJI="😈"
  elif [[ "${OSTYPE}" == "msys"* || "${OSTYPE}" == "mingw"* ]]; then
    OS_ICON="🪟"
    OS_NAME="Windows"
    OS_EMOJI="🪟"
  else
    OS_ICON="🌐"
    OS_NAME="Unknown"
    OS_EMOJI="🖥️"
  fi

  export OS_ICON OS_NAME OS_EMOJI
  return 0
}

#-----------------------------------------------------------------------------
# Function: git_status
#
# Description:
#   Gets git branch and status information for bash prompt.
#   * at the end of branch name indicates uncommitted changes.
#
# Arguments:
#   None
#
# Returns:
#   Formatted git branch and status or empty string if not in a git repository
#-----------------------------------------------------------------------------
git_status() {
  local branch dirty
  # Check if we're in a git repository
  if git rev-parse --git-dir > /dev/null 2>&1; then
    # Get branch name or commit hash if in detached HEAD state
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
    # Check if working directory has uncommitted changes
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      echo "${tmux_yellow}${branch}*${reset}"  # Yellow with * for dirty state
    else
      echo "${tmux_green}${branch}${reset}"    # Green for clean state
    fi
  fi
}

#-----------------------------------------------------------------------------
# Function: setup_zsh_git
#
# Description:
#   Configures Zsh vcs_info system for git status integration.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
setup_zsh_git() {
  autoload -Uz vcs_info
  precmd_vcs_info() { vcs_info }
  precmd_functions+=( precmd_vcs_info )
  setopt prompt_subst

  # Configure git status display formats
  # %b = branch name
  # Green (46) for clean branch, Yellow (226) for modified branch
  zstyle ':vcs_info:git:*' formats '%F{46}%b%f'
  zstyle ':vcs_info:git:*' actionformats '%F{226}%b%f'
  zstyle ':vcs_info:git:*' check-for-changes true
  zstyle ':vcs_info:git:*' stagedstr '*'
  zstyle ':vcs_info:git:*' unstagedstr '*'

  return 0
}

#-----------------------------------------------------------------------------
# Function: configure_bash_prompt
#
# Description:
#   Configures the prompt for Bash shells with git integration.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_bash_prompt() {
  # Get OS information
  get_os_info

  # Define color codes
  define_colors

  # Set prompt with OS icon, name, emoji, current directory, and git status
  PS1="${tmux_blue} ${OS_ICON} ${OS_NAME} ${OS_EMOJI} ${tmux_purple}❭ ${tmux_white}\w \$(git_status) ${tmux_red}\$ ${reset}"

  # Export prompt
  export PS1

  return 0
}

#-----------------------------------------------------------------------------
# Function: configure_zsh_prompt
#
# Description:
#   Configures the prompt for Zsh shells with git integration.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_zsh_prompt() {
  # Get OS information
  get_os_info

  # Setup git integration for Zsh
  setup_zsh_git

  # Set prompt with OS icon, name, emoji, current directory, and git status
  PROMPT="%F{33} ${OS_ICON} ${OS_NAME} ${OS_EMOJI} %F{55}❭ %F{15}%~ ${vcs_info_msg_0_} %F{196}\$ %f"

  # Export prompt
  export PROMPT

  return 0
}

#-----------------------------------------------------------------------------
# Function: configure_simple_prompt
#
# Description:
#   Configures a simple prompt for terminals with limited capabilities.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_simple_prompt() {
  if [[ -n "${BASH_VERSION}" ]]; then
    PS1='\h \w > '
    export PS1
  elif [[ -n "${ZSH_VERSION}" ]]; then
    PROMPT='%m %~ > '
    export PROMPT
  fi

  return 0
}

#-----------------------------------------------------------------------------
# Function: configure_prompt
#
# Description:
#   Main function to configure the appropriate prompt based on
#   shell type and terminal capabilities.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_prompt() {
  # Check if shell is interactive
  check_interactive_shell || return 0

  # Check terminal capabilities
  if ! check_terminal_capabilities; then
    configure_simple_prompt
    return 0
  fi

  # Configure shell-specific prompt
  if [[ -n "${BASH_VERSION}" ]]; then
    configure_bash_prompt
  elif [[ -n "${ZSH_VERSION}" ]]; then
    configure_zsh_prompt
  else
    # Unknown shell, use simple prompt
    configure_simple_prompt
  fi

  return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure prompt
configure_prompt
