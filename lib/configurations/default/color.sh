#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: color.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure terminal color settings and output formatting
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Function: configure_color_settings
#
# Description:
#   Configures color-related environment variables for terminal output.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_color_settings() {
    # Enable color output
    export colorflag='-G'

    # Enable colored output from ls, etc.
    export CLICOLOR=1
    export CLICOLOR_FORCE=1

    # Clear any existing color settings
    unset LSCOLORS LS_COLORS

    # Configure OS-specific color settings
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        # macOS specific colors
        export LSCOLORS="GxFxCxDxbxegedabagaced"
    elif [[ "${OSTYPE}" == "linux"* || "${OSTYPE}" == "freebsd"* ]]; then
        # Linux and FreeBSD colors
        export LS_COLORS="di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"
    else
        # Default for other systems
        echo "Notice: Unknown OS type '${OSTYPE}', using default color settings" >&2
        export LS_COLORS="di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"
    fi

    # Configure grep colors (GREP_OPTIONS is deprecated, using aliases instead)
    if command -v grep &> /dev/null; then
        # Ensure we're not overriding any existing aliases
        unalias grep 2>/dev/null || true
        unalias fgrep 2>/dev/null || true
        unalias egrep 2>/dev/null || true

        # Set up color aliases for grep commands
        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
    else
        echo "Warning: grep command not found, color aliases not set" >&2
    fi

    return 0
}

#-----------------------------------------------------------------------------
# Function: setup_ls_aliases
#
# Description:
#   Sets up ls aliases with appropriate color flags.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
setup_ls_aliases() {
    if command -v ls &> /dev/null; then
        # Ensure we're not overriding any existing aliases
        unalias ls 2>/dev/null || true
        unalias ll 2>/dev/null || true
        unalias la 2>/dev/null || true

        # Determine appropriate ls flags based on OS
        local ls_color_flag='-G'  # Default for BSD/macOS

        if [[ "${OSTYPE}" == "linux"* ]]; then
            ls_color_flag='--color=auto'
        fi

        # Set up ls aliases with color support
        # shellcheck disable=SC2139
        alias ls="ls ${ls_color_flag}"
        # shellcheck disable=SC2139
        alias ll="ls -lh ${ls_color_flag}"
        # shellcheck disable=SC2139
        alias la="ls -lah ${ls_color_flag}"
    else
        echo "Warning: ls command not found, aliases not set" >&2
    fi

    return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure color settings
configure_color_settings

# Setup ls aliases
setup_ls_aliases
