#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Python Development Environment Configuration
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT
#
# Description:
#   Configuration file for Python development environment, including aliases,
#   environment variables, and utility functions for common Python tasks.
#
################################################################################

# Environment Variables
export PYTHONIOENCODING='UTF-8'           # Set UTF-8 encoding for Python I/O
export PYTHONUTF8=1                       # Enable UTF-8 mode for Python
export PYTHONDONTWRITEBYTECODE=1          # Prevent Python from writing .pyc files
export PYTHONUNBUFFERED=1                 # Force Python output to be unbuffered
export PYENV_VIRTUALENV_DISABLE_PROMPT=1   # Disable virtualenv prompt modification

# Frameworks and Applications
# Add Python 3.12 or the Homebrew Python to PATH
if command -v /opt/homebrew/bin/python3 >/dev/null; then
    export PATH="/opt/homebrew/bin:${PATH}"
elif command -v /Library/Frameworks/Python.framework/Versions/3.12/bin/python3 >/dev/null; then
    export PATH="/Library/Frameworks/Python.framework/Versions/3.12/bin:${PATH}"
fi

if command -v 'python3' >/dev/null; then
    # Python Version Management
    python() {
        command python3 "$@"
    }

    pip() {
        command pip3 "$@"
    }

    # Basic Python Commands
    alias py='python'                     # Quick Python access
    alias ipy='ipython'                   # Interactive Python shell
    alias pyv='python --version'          # Show Python version
    alias pydoc='python -m pydoc'         # Python documentation

    # Package Management
    alias pipi='pip install'              # Install packages
    alias pipl='pip list'                 # List installed packages
    alias pipup='pip install --upgrade'    # Upgrade packages
    alias pipun='pip uninstall -y'        # Uninstall packages
    alias pipf='pip freeze'               # Show frozen requirements
    alias pipr='pip install -r'           # Install from requirements
    alias pipout='pip freeze > requirements.txt'  # Save requirements

    # Development Tools
    alias pep8='autopep8'                 # Code formatting
    alias lint='pylint'                   # Code linting
    alias black='python -m black'         # Code formatting with black
    alias mypy='python -m mypy'           # Static type checking
    alias ruff='python -m ruff'           # Fast Python linter

    # Testing
    alias pytest='python -m pytest'        # Run tests
    alias pytestv='pytest -v'             # Verbose test output
    alias pytestc='pytest --cov'          # Test coverage
    alias unittest='python -m unittest'    # Run unittest

    # Virtual Environment Management
    alias venv='python -m venv'           # Create virtual environment
    alias mkvenv='python -m venv ./venv'  # Create venv in current directory
    alias venva='source ./venv/bin/activate'  # Activate venv
    alias deact='deactivate'              # Deactivate venv
    alias rmvenv='rm -rf ./venv'          # Remove venv

    # Cleanup
    alias rmpyc="find . -type f -name '*.pyc' -delete"  # Remove .pyc files
    alias rmpyo="find . -type f -name '*.pyo' -delete"  # Remove .pyo files
    alias rmpyall="find . -type f -name '*.py[cod]' -delete && find . -type d -name __pycache__ -delete"  # Remove all

    # Utility Functions
    python_speed() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_speed 'Python code here'"
            return 1
        fi
        python -m timeit -s "$1"
    }

    python_profile() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_profile script.py"
            return 1
        fi
        python -m cProfile "$1"
    }

    python_debug() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_debug script.py"
            return 1
        fi
        python -m pdb "$1"
    }

    python_serve() {
        local port="${1:-8000}"
        python -m http.server "$port"
    }

    # Project Templates
    python_new_project() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_new_project project_name"
            return 1
        fi
        local project_name="$1"
        mkdir -p "$project_name"/{src,tests,docs}
        touch "$project_name/README.md"
        touch "$project_name/requirements.txt"
        touch "$project_name/setup.py"
        touch "$project_name/src/__init__.py"
        touch "$project_name/tests/__init__.py"
        echo "Created new Python project structure in ./$project_name"
    }

    # Environment Information
    python_info() {
        echo "Python Version:"
        python --version
        echo -e "\nPip Version:"
        pip --version
        echo -e "\nVirtual Environment:"
        if [ -n "$VIRTUAL_ENV" ]; then
            echo "Active: $VIRTUAL_ENV"
        else
            echo "None active"
        fi
        echo -e "\nInstalled Packages:"
        pip list
    }
fi