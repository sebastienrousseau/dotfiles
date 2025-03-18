#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: prompt.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure shell prompts for various environments
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
# Function: get_os_icon
#
# Description:
#   Determines the appropriate OS icon for the prompt.
#
# Arguments:
#   None
#
# Returns:
#   String containing the OS-specific icon
#-----------------------------------------------------------------------------
get_os_icon() {
    local os_icon=""

    if [[ "${OSTYPE}" == "darwin"* ]]; then
        os_icon=" "  # Apple icon for macOS
    elif [[ "${OSTYPE}" == "linux"* ]]; then
        os_icon=" 🐧"  # Penguin icon for Linux
    elif [[ "${OSTYPE}" == "freebsd"* ]]; then
        os_icon=" 😈"  # Devil icon for FreeBSD
    elif [[ "${OSTYPE}" == "win"* || "${OSTYPE}" == "msys"* || "${OSTYPE}" == "mingw"* ]]; then
        os_icon=" "  # Windows icon
    else
        os_icon=" "  # Generic computer icon for other systems
    fi

    echo "${os_icon}"
}

#-----------------------------------------------------------------------------
# Function: configure_bash_prompt
#
# Description:
#   Configures the prompt for Bash shells.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_bash_prompt() {
    # Define colors
    local cyan='\[\033[1;96m\]'
    local green='\[\033[1;92m\]'
    local purple='\[\033[1;95m\]'
    local reset='\[\033[0m\]'
    local yellow='\[\033[1;93m\]'

    # Get OS information
    local os_name
    if ! os_name=$(uname 2>/dev/null); then
        os_name="Unknown"
    fi

    # Get OS icon
    local os_icon
    os_icon=$(get_os_icon)

    # Set prompt
    PS1="${os_icon} ${yellow}${os_name}${purple} ❭${reset} ${green}\w${reset} ${cyan}$ ${reset}"

    # Export prompt
    export PS1

    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_zsh_prompt
#
# Description:
#   Configures the prompt for Zsh shells.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_zsh_prompt() {
    # Get OS icon
    local os_icon
    os_icon=$(get_os_icon)

    # Set prompt
    PROMPT="${os_icon} %F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f"

    # Optional right-side prompt with time
    RPROMPT='%F{cyan}%T%f'

    # Export prompts
    export PROMPT
    export RPROMPT

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
