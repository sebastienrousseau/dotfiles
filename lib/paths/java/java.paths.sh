#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: java.paths.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure Java environment paths and options
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Java version configuration
JAVA_VERSION="23.0.1"
JAVA_MAJOR_VERSION="23"

#-----------------------------------------------------------------------------
# Function: configure_java_paths
#
# Description:
#   Configures Java-related paths based on the operating system.
#   Supports both macOS (Homebrew) and Linux environments.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#-----------------------------------------------------------------------------
configure_java_paths() {
    # macOS specific configuration
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        local java_brew_path="/opt/homebrew/Cellar/openjdk/${JAVA_VERSION}/libexec/openjdk.jdk/Contents/Home"
        local java_include_path="/opt/homebrew/opt/openjdk/include"

        if [[ -d "${java_brew_path}" ]]; then
            export JAVA_HOME="${java_brew_path}"
            export PATH="/opt/homebrew/opt/openjdk/bin:${PATH}"

            # Set C/C++ flags for JNI development
            if [[ -d "${java_include_path}" ]]; then
                export CPPFLAGS="-I${java_include_path}"
            else
                echo "Warning: Java include path not found: ${java_include_path}" >&2
            fi
        else
            echo "Warning: Java not found in Homebrew path: ${java_brew_path}" >&2
            return 1
        fi

    # Linux specific configuration
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local java_path="/usr/lib/jvm/java-${JAVA_MAJOR_VERSION}-openjdk-arm64"
        if [[ -d "${java_path}" ]]; then
            export JAVA_HOME="${java_path}"
        else
            echo "Warning: Java not found at ${java_path}" >&2
            return 1
        fi

    else
        echo "Warning: Unsupported operating system" >&2
        return 1
    fi

    # Verify Java installation
    if command -v java >/dev/null; then
        local installed_version
        installed_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        if [[ "${installed_version}" != "${JAVA_VERSION}"* ]]; then
            echo "Warning: Installed Java version (${installed_version}) differs from expected version (${JAVA_VERSION})" >&2
        fi
    else
        echo "Warning: Java command not found in PATH" >&2
        return 1
    fi

    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_java_environment
#
# Description:
#   Configures additional Java environment variables and options.
#
# Arguments:
#   None
#
# Returns:
#   None
#-----------------------------------------------------------------------------
configure_java_environment() {
    # Set JRE_HOME if it exists
    if [[ -d "${JAVA_HOME}/jre" ]]; then
        export JRE_HOME="${JAVA_HOME}/jre"
    fi

    # Additional Java environment variables
    export _JAVA_OPTIONS="${_JAVA_OPTIONS:--Xms512m -Xmx2g}"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Dfile.encoding=UTF8}"
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure Java paths
configure_java_paths

# Configure Java environment
configure_java_environment
