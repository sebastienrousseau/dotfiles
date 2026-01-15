#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: constants.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Define constants and variables for dotfiles configuration
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Function: configure_dotfiles_constants
#
# Description:
#   Sets up common dotfiles paths and version information.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_dotfiles_constants() {
    # Dotfiles paths
    DF=".dotfiles/"                         # Dotfiles.
    DF_DIR="${HOME}/.dotfiles/"             # Dotfiles directory.
    DF_BACKUPDIR="${HOME}/dotfiles_backup/" # Backup directory.
    DF_DOWNLOADDIR="${HOME}/Downloads"      # Download directory.
    DF_VERSION="0.2.470"                    # Dotfiles Version number.

    # Create a timestamp for backup operations if needed
    # Uncomment the next line to enable timestamp generation
    # DF_TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)" # Timestamp for backup directory.

    # Create backup directory if it doesn't exist
    if [[ ! -d "${DF_BACKUPDIR}" ]]; then
        mkdir -p "${DF_BACKUPDIR}" || {
            echo "Warning: Failed to create backup directory: ${DF_BACKUPDIR}" >&2
        }
    fi

    # Create download directory if it doesn't exist
    if [[ ! -d "${DF_DOWNLOADDIR}" ]]; then
        mkdir -p "${DF_DOWNLOADDIR}" || {
            echo "Warning: Failed to create download directory: ${DF_DOWNLOADDIR}" >&2
        }
    fi

    # Export dotfiles constants
    export DF
    export DF_BACKUPDIR
    export DF_DIR
    export DF_DOWNLOADDIR
    export DF_VERSION
    # export DF_TIMESTAMP   # Uncomment if DF_TIMESTAMP is enabled

    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_terminal_colors
#
# Description:
#   Configures terminal color constants for consistent output formatting.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#-----------------------------------------------------------------------------
configure_terminal_colors() {
    # Check if tput is available
    if ! command -v tput &> /dev/null; then
        echo "Warning: tput command not found, terminal colors will not be available" >&2
        # Set fallback empty color variables if tput not available
        BLACK=""
        BLUE=""
        CYAN=""
        GREEN=""
        NC=""
        PURPLE=""
        RED=""
        WHITE=""
        YELLOW=""
    else
        # Set terminal colors using tput
        BLACK="$(tput setaf 0)"               # Black
        BLUE="$(tput bold && tput setaf 4)"   # Blue
        CYAN="$(tput bold && tput setaf 6)"   # Cyan
        GREEN="$(tput bold && tput setaf 2)"  # Green
        NC="$(tput sgr0)"                     # No Color
        PURPLE="$(tput bold && tput setaf 5)" # Purple
        RED="$(tput bold && tput setaf 1)"    # Red
        WHITE="$(tput bold && tput setaf 7)"  # White
        YELLOW="$(tput bold && tput setaf 3)" # Yellow
    fi

    # Export terminal colors
    export BLACK
    export BLUE
    export CYAN
    export GREEN
    export NC
    export PURPLE
    export RED
    export WHITE
    export YELLOW

    return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure dotfiles constants
configure_dotfiles_constants || echo "Warning: Failed to configure dotfiles constants" >&2

# Configure terminal colors
configure_terminal_colors || echo "Warning: Failed to configure terminal colors" >&2
