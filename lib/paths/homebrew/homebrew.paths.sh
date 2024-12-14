#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: homebrew.paths.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure Homebrew environment paths and options
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Function: configure_homebrew_paths
#
# Description:
#   Configures Homebrew-related paths and environment variables.
#   Only runs on macOS systems.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 if not on macOS or Homebrew not found
#-----------------------------------------------------------------------------
configure_homebrew_paths() {
    # Check if running on macOS
    if [[ "${OSTYPE}" != "darwin"* ]]; then
        echo "Warning: Homebrew configuration is only for macOS systems" >&2
        return 1
    fi # Fixed: Added missing 'fi'

    # Check if Homebrew is installed
    if ! command -v brew >/dev/null; then
        echo "Warning: Homebrew is not installed" >&2
        return 1
    fi

    # Base Homebrew paths
    local homebrew_prefix="/opt/homebrew"

    # Verify Homebrew directories exist
    if [[ ! -d "${homebrew_prefix}" ]]; then
        echo "Warning: Homebrew prefix directory not found: ${homebrew_prefix}" >&2
        return 1
    fi

    # Configure PATH entries
    local paths=(
        "${homebrew_prefix}/bin"     # Homebrew binaries
        "${homebrew_prefix}/sbin"    # Homebrew system binaries
        "${homebrew_prefix}/bin/bash" # Homebrew bash
    )

    # Add paths to PATH if they exist
    for path in "${paths[@]}"; do
        if [[ -d "${path}" ]]; then
            PATH="${path}:${PATH}"
        else
            echo "Warning: Homebrew path not found: ${path}" >&2
        fi
    done

    export PATH
    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_homebrew_options
#
# Description:
#   Configures Homebrew behavior and preferences.
#
# Arguments:
#   None
#
# Returns:
#   None
#-----------------------------------------------------------------------------
configure_homebrew_options() {
    # Disable Homebrew analytics
    # See: https://github.com/Homebrew/brew/blob/master/share/doc/homebrew/Analytics.md
    export HOMEBREW_NO_ANALYTICS=1

    # Set auto-update frequency (seconds)
    # Default: Update once per day (86400 seconds)
    export HOMEBREW_AUTO_UPDATE_SECS=86400

    # Configure Homebrew Cask options
    export HOMEBREW_CASK_OPTS="--appdir=/Applications"

    # Additional Homebrew preferences
    export HOMEBREW_NO_ENV_HINTS=1          # Disable environment hints
    export HOMEBREW_BAT=1                   # Use bat for JSON output
    export HOMEBREW_DISPLAY_INSTALL_TIMES=1 # Show install times
    export HOMEBREW_NO_INSECURE_REDIRECT=1  # Prevent insecure redirects
    export HOMEBREW_NO_AUTO_UPDATE=1        # Disable auto updates
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure Homebrew paths
configure_homebrew_paths

# Configure Homebrew options
configure_homebrew_options
