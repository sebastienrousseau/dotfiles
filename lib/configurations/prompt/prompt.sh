#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: prompt.sh
# Version: 0.2.470
# Author: Sebastien Rousseau (Updated by Assistant)
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure shell prompts for various environments.
# Website: https://dotfiles.io
# License: MIT
#
# This script supports both Bash and Zsh. It is intended to be sourced in your
# interactive shell initialization file (e.g., ~/.bashrc, ~/.zshrc).
################################################################################

#-----------------------------------------------------------------------------
# Function: log_warning
#
# Description:
#   Logs a warning message to stderr.
#
# Arguments:
#   Message string
#
# Returns:
#   None
#-----------------------------------------------------------------------------
log_warning() {
    echo "Warning: $*" >&2
}

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
    if [[ "$-" != *i* ]]; then
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
    # Check if TERM is set
    if [[ -z "${TERM}" ]]; then
        return 1
    fi

    # Check if terminal supports 256 colors, is Alacritty, or is Kitty
    if [[ "${TERM}" != *-256color* && "${TERM}" != alacritty* && "${TERM}" != *-kitty* ]]; then
        return 1
    fi

    # Optional: Check for true color support
    if [[ -z "${COLORTERM}" || ( "${COLORTERM}" != "truecolor" && "${COLORTERM}" != "24bit" ) ]]; then
        log_warning "Terminal may not support true color (24-bit color)"
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

    # Allow user customization through environment variables
    if [[ -n "${CUSTOM_OS_ICON}" ]]; then
        os_icon="${CUSTOM_OS_ICON}"
        echo "${os_icon}"
        return 0
    fi

    if [[ "${OSTYPE}" == darwin* ]]; then
        os_icon=""  # Apple icon for macOS
    elif [[ "${OSTYPE}" == linux* ]]; then
        os_icon="🐧"  # Penguin icon for Linux
    elif [[ "${OSTYPE}" == freebsd* ]]; then
        os_icon="😈"  # Devil icon for FreeBSD
    elif [[ "${OSTYPE}" == win* || "${OSTYPE}" == msys* || "${OSTYPE}" == mingw* ]]; then
        os_icon="🪟"  # Windows icon
    else
        os_icon="💻"  # Generic computer icon for unknown systems
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
    # Define colors with default values
    local cyan='\[\033[1;96m\]'
    local green='\[\033[1;92m\]'
    local purple='\[\033[1;95m\]'
    local yellow='\[\033[1;93m\]'
    local reset='\[\033[0m\]'

    # Allow color customization through environment variables
    [[ -n "${PROMPT_CYAN}" ]] && cyan="${PROMPT_CYAN}"
    [[ -n "${PROMPT_GREEN}" ]] && green="${PROMPT_GREEN}"
    [[ -n "${PROMPT_PURPLE}" ]] && purple="${PROMPT_PURPLE}"
    [[ -n "${PROMPT_YELLOW}" ]] && yellow="${PROMPT_YELLOW}"

    # Get OS information
    local os_name
    if ! os_name=$(uname 2>/dev/null); then
        os_name="Unknown"
        log_warning "Unable to determine OS name using uname command"
    fi

    # Get OS icon
    local os_icon
    os_icon=$(get_os_icon)

    # Set prompt symbol (allow customization)
    local prompt_symbol="❭"
    [[ -n "${CUSTOM_PROMPT_SYMBOL}" ]] && prompt_symbol="${CUSTOM_PROMPT_SYMBOL}"

    # Set the prompt string
    PS1="${os_icon} ${yellow}${os_name}${purple} ${prompt_symbol}${reset} ${green}\w${reset} ${cyan}\$${reset} "

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
    # Enable prompt substitution for dynamic content
    setopt PROMPT_SUBST

    # Get OS icon
    local os_icon
    os_icon=$(get_os_icon)

    # Set prompt symbol (allow customization)
    local prompt_symbol="❭"
    [[ -n "${CUSTOM_PROMPT_SYMBOL}" ]] && prompt_symbol="${CUSTOM_PROMPT_SYMBOL}"

    # Set the main prompt
    PROMPT="${os_icon} %F{yellow}%m%f ${prompt_symbol} %F{green}%~%f %F{cyan}$ %f"

    # Optional right-side prompt with time
    RPROMPT='%F{cyan}%T%f'

    # Export prompts for consistency
    export PROMPT RPROMPT

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
    elif [[ -n "${ZSH_VERSION}" ]]; then
        PROMPT='%m %~ > '
        setopt PROMPT_SUBST
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
    # Only proceed if the shell is interactive
    check_interactive_shell || return 0

    # Check terminal capabilities
    local fancy_terminal=true
    if ! check_terminal_capabilities; then
        fancy_terminal=false
    fi

    # Allow users to force a simple prompt regardless of terminal capabilities
    if [[ "${FORCE_SIMPLE_PROMPT}" == "true" ]]; then
        fancy_terminal=false
    fi

    # Configure the shell-specific prompt based on capabilities
    if [[ "${fancy_terminal}" == "false" ]]; then
        configure_simple_prompt
    else
        if [[ -n "${BASH_VERSION}" ]]; then
            configure_bash_prompt
        elif [[ -n "${ZSH_VERSION}" ]]; then
            configure_zsh_prompt
        else
            # Fallback to a simple prompt if the shell is unrecognized
            configure_simple_prompt
        fi
    fi

    return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Only run prompt configuration when the script is sourced in an interactive shell.
check_interactive_shell && configure_prompt
