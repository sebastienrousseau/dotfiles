#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Change Directory and List Contents (cdls)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   cdls is a simple function that combines the functionality of `cd` and `ls`.
#   When called, it changes the current working directory and immediately lists
#   the contents of the new directory.
#
# Usage:
#   cdls [directory]
#   cdls --help
#
# Arguments:
#   directory    The directory to change to. If omitted, changes to the home
#                directory (default behavior of `cd`).
#   --help       Displays this help menu and exits.
#
# Examples:
#   cdls /tmp    # Changes to the /tmp directory and lists its contents.
#   cdls         # Changes to the home directory and lists its contents.
#   cdls --help  # Displays the help menu.
#
################################################################################

# Function to combine cd and ls
cdls() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "cdls: Change Directory and List Contents"
    echo
    echo "Usage:"
    echo "  cdls [directory]"
    echo "  cdls --help"
    echo
    echo "Aliases:"
    echo "  alias cdl='cdls' # Alias for cdls to simplify usage"
    echo
    echo "Arguments:"
    echo "  directory    The directory to change to. If omitted, changes to the home"
    echo "               directory (default behavior of \`cd\`)."
    echo "  --help       Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  cdls /tmp    # Changes to the /tmp directory and lists its contents."
    echo "  cdls         # Changes to the home directory and lists its contents."
    echo "  cdls --help  # Displays the help menu."
    echo
    return 0
  fi

  # Change to the specified directory and list its contents
  cd "$@" && ls
}

# Alias for convenience
alias cdl='cdls' # Alias for cdls to simplify usage
