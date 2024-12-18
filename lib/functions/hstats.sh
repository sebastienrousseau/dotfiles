#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - History Statistics Viewer (hstats)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   hstats is a utility function to display statistics about the most commonly
#   used commands from the shell history. It shows the top 20 commands along
#   with their usage count and the full command.
#
# Usage:
#   hstats
#   hstats --help
#
# Arguments:
#   --help      Displays this help menu and exits.
#
# Examples:
#   hstats
#       # Displays the top 20 most commonly used commands from shell history.
#
#   hstats --help
#       # Displays the help menu.
#
################################################################################

hstats() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "hstats: History Statistics Viewer"
    echo
    echo "Usage:"
    echo "  hstats"
    echo "  hstats --help"
    echo
    echo "Arguments:"
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  hstats"
    echo "      # Displays the top 20 most commonly used commands from shell history."
    echo
    echo "  hstats --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Ensure the history command is available
  if ! command -v history &>/dev/null; then
    echo "[ERROR] 'history' command is not available in this shell." >&2
    return 1
  fi

  # Extract only the commands from history, removing timestamps or extra metadata
  if [[ "$SHELL" =~ "zsh" ]]; then
    # For zsh, use `fc -l` to get clean commands
    history_output=$(fc -l 1 | awk '{$1=""; print $0}')
  else
    # For bash, use `history` directly
    history_output=$(history | awk '{$1=""; print $0}')
  fi

  # Generate statistics
  echo "============================================"
  echo "Commonly Used Commands"
  echo "============================================"
  echo "$history_output" | awk '{CMD[$1]++; count++;} END {for (a in CMD) printf "%-15s %s\n", CMD[a], a;}' \
    | sort -nr \
    | head -n20 \
    | nl
  echo "============================================"
}
