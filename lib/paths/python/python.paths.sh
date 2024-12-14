#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: python.paths.sh
# Version: 0.2.469
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure Python environment variables, paths and aliases
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Python version configuration
PYTHON_VERSION="3.13.1"
PYTHON_MAJOR="3"

#-----------------------------------------------------------------------------
# Function: configure_python_paths
#
# Description:
#   Configures Python-related paths and environment variables based on the
#   operating system. Supports both macOS and Linux environments.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#
# Usage:
#   configure_python_paths
#-----------------------------------------------------------------------------
configure_python_paths() {
    # macOS specific configuration
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        local python_framework="/Library/Frameworks/Python.framework/Versions/${PYTHON_VERSION}"
        if [[ -d "${python_framework}/bin" ]]; then
            export PATH="${python_framework}/bin:${PATH}"
            export PYTHONHOME="${python_framework}"
        else
            echo "Warning: Python framework not found at ${python_framework}" >&2
            return 1
        fi

    # Linux specific configuration
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        local python_path="/usr/bin/python${PYTHON_VERSION}"
        if [[ -d "${python_path}" ]]; then
            export PATH="/usr/bin:${PATH}"
            export PYTHONHOME="/usr"
        else
            echo "Warning: Python not found at ${python_path}" >&2
            return 1
        fi
    fi

    return 0
}

#-----------------------------------------------------------------------------
# Function: configure_python_environment
#
# Description:
#   Sets up Python environment variables for optimal operation and compatibility.
#
# Arguments:
#   None
#
# Returns:
#   None
#-----------------------------------------------------------------------------
configure_python_environment() {
    # Character encoding configuration
    export PYTHONIOENCODING='UTF-8'      # Encoding used for stdin/stdout/stderr
    export PYTHONUTF8=1                  # Enable UTF-8 mode

    # Development environment optimization
    export PYTHONDONTWRITEBYTECODE=1     # Prevent creation of .pyc files
    export PYTHONUNBUFFERED=1            # Force buffering of stdout/stderr

    # Custom startup configuration
    if [[ -f "${HOME}/.pythonrc" ]]; then
        export PYTHONSTARTUP="${HOME}/.pythonrc"
    fi

    # Virtual environment support
    if [[ -n "${VIRTUAL_ENV}" ]]; then
        PATH="${VIRTUAL_ENV}/bin:${PATH}"
    fi
}

#-----------------------------------------------------------------------------
# Function: configure_python_aliases
#
# Description:
#   Sets up aliases for common Python commands and tools.
#
# Arguments:
#   None
#
# Returns:
#   None
#-----------------------------------------------------------------------------
configure_python_aliases() {
    if command -v "python${PYTHON_MAJOR}" >/dev/null; then
        # Core Python aliases
        alias python="python\${PYTHON_MAJOR}"         # Default python version
        alias python3="python\${PYTHON_VERSION}"      # Specific python3 version
        alias py='python'                             # Short form for python

        # Package management aliases
        alias pip="pip\${PYTHON_MAJOR}"               # Default pip version
        alias pipup='pip install --upgrade pip'       # Upgrade pip
        alias piplist='pip list --outdated'           # List outdated packages

        # Development tool aliases
        alias ipy='ipython'                          # Interactive Python
        alias pytest='python -m pytest'               # Testing
        alias pyenv='python -m venv'                 # Virtual environment
        alias pyprof='python -m cProfile'            # Profiling
        alias pydoc='python -m pydoc'                # Documentation
        alias pep8='autopep8'                        # Code formatting

        # Debugging aliases
        alias pdb='python -m pdb'                    # Debug
        alias pytrace='python -m trace'              # Trace execution
    else
        echo "Warning: Python ${PYTHON_MAJOR} not found in PATH" >&2
    fi
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure Python paths
configure_python_paths

# Set up Python environment variables
configure_python_environment

# Set up Python aliases
configure_python_aliases
