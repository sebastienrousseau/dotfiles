#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Environment Detector (environment)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   environment is a function that detects the current operating system
#   environment. It identifies whether the system is macOS, Linux, or Windows
#   (including Cygwin and MING environments).
#
# Usage:
#   environment
#   environment --help
#
# Arguments:
#   --help      Displays this help menu and exits.
#
# Examples:
#   environment
#       # Detects and displays the current operating system environment.
#
#   environment --help
#       # Displays the help menu.
#
################################################################################

# Function to detect the current environment
environment() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "environment: Environment Detector"
    echo
    echo "Usage:"
    echo "  environment"
    echo "  environment --help"
    echo
    echo "Arguments:"
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  environment"
    echo "      # Detects and displays the current operating system environment."
    echo
    echo "  environment --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Detect the environment
  LOCAL_OS="other"  # Fallback OS

  # macOS
  if [[ "$(uname -s | grep -c Darwin)" -gt 0 ]]; then
    LOCAL_OS="mac"

  # Linux
  elif [[ "$(uname -s | grep -c Linux)" -gt 0 ]]; then
    LOCAL_OS="linux"

  # Windows via MING
  elif [[ "$(uname -s | grep -c MING)" -gt 0 ]]; then
    LOCAL_OS="win"

  # Cygwin
  elif [[ "$(uname -s | grep -c Cygwin)" -gt 0 ]]; then
    LOCAL_OS="win"

  # Cygwin via Babun
  elif [[ "$(uname -s | grep -c CYGWIN)" -gt 0 ]]; then
    LOCAL_OS="win"
  fi

  # Output the result
  echo "${LOCAL_OS}"
}
