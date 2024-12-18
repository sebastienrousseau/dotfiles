#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Change Directory Helper (goto)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   goto is a utility function to quickly navigate to a specified directory.
#   It changes to the given directory and lists its contents.
#
# Usage:
#   goto [directory]
#   goto --help
#
# Arguments:
#   directory    The directory to navigate to.
#   --help       Displays this help menu and exits.
#
# Examples:
#   goto /tmp
#       # Changes to the /tmp directory and lists its contents.
#
#   goto --help
#       # Displays the help menu.
#
################################################################################

# Function to change to the specified directory and list its contents
goto() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "goto: Change Directory Helper"
    echo
    echo "Usage:"
    echo "  goto [directory]"
    echo "  goto --help"
    echo
    echo "Arguments:"
    echo "  directory    The directory to navigate to."
    echo "  --help       Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  goto /tmp"
    echo "      # Changes to the /tmp directory and lists its contents."
    echo
    echo "  goto --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Check if a directory is provided
  if [[ -z "$1" ]]; then
    echo "[ERROR] No directory provided. Use 'goto --help' for usage information." >&2
    return 1
  fi

  # Check if the directory exists
  if [[ -d "$1" ]]; then
    cd "$1" || return
    ls -lh --group-directories-first
  else
    echo "[ERROR] '$1' is not a valid directory." >&2
    return 1
  fi
}
