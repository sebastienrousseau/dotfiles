#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: maven.paths.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure Maven environment paths and options
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Maven version configuration
MAVEN_VERSION="3.9.9"
MAVEN_MIN_MEMORY="1g"
MAVEN_MAX_MEMORY="1g"

#-----------------------------------------------------------------------------
# Function: configure_maven_paths
#
# Description:
#   Configures Maven-related paths based on the operating system.
#   Supports both macOS (Homebrew) and Linux environments.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#-----------------------------------------------------------------------------
configure_maven_paths() {
    # macOS specific configuration
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        local maven_brew_path="/opt/homebrew/Cellar/maven/${MAVEN_VERSION}/libexec"
        if [[ -d "${maven_brew_path}" ]]; then
            export M2_HOME="${maven_brew_path}"
            export MAVEN_HOME="${maven_brew_path}"
        else
            echo "Warning: Maven not found in Homebrew path: ${maven_brew_path}" >&2
            return 1
        fi

    # Linux specific configuration
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local maven_path="/usr/share/maven"
        if [[ -d "${maven_path}" ]]; then
            export MAVEN_HOME="${maven_path}"
        else
            echo "Warning: Maven not found at ${maven_path}" >&2
            return 1
        fi

    else
        echo "Warning: Unsupported operating system" >&2
        return 1
    fi

    # Verify maven installation
    if command -v mvn >/dev/null; then
        local installed_version
        installed_version=$(mvn --version | grep "Apache Maven" | awk '{print $3}')
        if [[ "${installed_version}" != "${MAVEN_VERSION}" ]]; then
            echo "Warning: Installed Maven version (${installed_version}) differs from expected version (${MAVEN_VERSION})" >&2
        fi
    else
        echo "Warning: Maven command not found in PATH" >&2
        return 1
    fi

    # Configure Maven paths
    export PATH="${MAVEN_HOME}/bin:${PATH}"

    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_maven_options
#
# Description:
#   Configures Maven options including memory settings and other JVM options.
#
# Arguments:
#   None
#
# Returns:
#   None
#-----------------------------------------------------------------------------
configure_maven_options() {
    # Set Maven memory options
    export MAVEN_OPTS="-Xms${MAVEN_MIN_MEMORY} -Xmx${MAVEN_MAX_MEMORY}"

    # Additional Maven environment variables
    export M2_REPO="${HOME}/.m2/repository"
    export MAVEN_ARGS="${MAVEN_ARGS:---fail-fast}"
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure Maven paths
configure_maven_paths

# Configure Maven options
configure_maven_options
