#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: ruby.paths.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure Ruby and Gem environment paths
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Ruby version configuration
RUBY_VERSION="3.3.0"

#-----------------------------------------------------------------------------
# Function: configure_ruby_paths
#
# Description:
#   Configures Ruby-related paths based on the operating system.
#   Supports both macOS (Homebrew) and Linux environments.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#-----------------------------------------------------------------------------
configure_ruby_paths() {
    # macOS specific configuration
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        if [[ -d "/opt/homebrew/opt/ruby/bin" ]]; then
            RUBY_HOME="/opt/homebrew/opt/ruby/bin"
        else
            echo "Warning: Ruby not found in Homebrew path" >&2
            return 1
        fi
    # Linux specific configuration
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local ruby_path="/usr/lib/ruby/${RUBY_VERSION}"
        if [[ -d "${ruby_path}" ]]; then
            RUBY_HOME="${ruby_path}"
        else
            echo "Warning: Ruby not found at ${ruby_path}" >&2
            return 1
        fi
    else
        echo "Warning: Unsupported operating system" >&2
        return 1
    fi

    export RUBY_HOME
    export PATH="${RUBY_HOME}:${PATH}"
    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_gem_paths
#
# Description:
#   Configures RubyGems-related paths and environment variables.
#   Sets up GEM_HOME and GEM_PATH for proper gem management.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#-----------------------------------------------------------------------------
configure_gem_paths() {
    if command -v gem >/dev/null; then
        # Get the gem directory from the gem environment
        GEM_HOME="$(gem environment gemdir)"
        if [[ -z "${GEM_HOME}" ]]; then
            echo "Warning: Failed to determine GEM_HOME" >&2
            return 1
        fi

        GEM_PATH="${GEM_HOME}"

        # Export gem-related variables
        export GEM_HOME
        export GEM_PATH
        export PATH="${GEM_PATH}:${PATH}"
        export PATH="${GEM_HOME}:${PATH}"
    else
        echo "Warning: gem command not found" >&2
        return 1
    fi
    return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure Ruby paths
configure_ruby_paths

# Configure Gem paths
configure_gem_paths
