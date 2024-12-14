#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: node.paths.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure Node.js environment paths
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Node.js version configuration
NODE_VERSION="23.4.0"
NODE_VERSION_NO_V="${NODE_VERSION#v}"  # Remove 'v' prefix if present

#-----------------------------------------------------------------------------
# Function: configure_node_paths
#
# Description:
#   Configures Node.js-related paths based on the operating system.
#   Supports both macOS (Homebrew) and Linux (NVM) environments.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#-----------------------------------------------------------------------------
configure_node_paths() {
    # macOS specific configuration
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        local node_brew_path="/opt/homebrew/Cellar/node/${NODE_VERSION_NO_V}"
        if [[ -d "${node_brew_path}" ]]; then
            NODE_PATH="${node_brew_path}"
        else
            echo "Warning: Node.js not found in Homebrew path: ${node_brew_path}" >&2
            return 1
        fi

    # Linux specific configuration
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local node_nvm_path="${HOME}/.nvm/versions/node/v${NODE_VERSION_NO_V}/bin/node"
        if [[ -f "${node_nvm_path}" ]]; then
            NODE_PATH="${node_nvm_path}"
        else
            echo "Warning: Node.js not found at ${node_nvm_path}" >&2
            return 1
        fi

    else
        echo "Warning: Unsupported operating system" >&2
        return 1
    fi

    # Verify node installation
    if command -v node >/dev/null; then
        local installed_version
        installed_version=$(node --version)
        if [[ "${installed_version}" != "v${NODE_VERSION_NO_V}" ]]; then
            echo "Warning: Installed Node.js version (${installed_version}) differs from expected version (v${NODE_VERSION_NO_V})" >&2
        fi
    else
        echo "Warning: Node.js command not found in PATH" >&2
        return 1
    fi

    # Export Node.js related variables
    export NODE_PATH
    export PATH="${NODE_PATH}:${PATH}"

    # Additional Node.js environment variables
    export NODE_ENV="${NODE_ENV:-development}"  # Set default environment
    export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=4096}"  # Set default memory limit

    return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure Node.js paths
configure_node_paths
