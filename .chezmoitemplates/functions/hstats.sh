# shellcheck shell=bash
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

  # Generate statistics (single awk pass, avoids intermediate variable)
  echo "============================================"
  echo "Commonly Used Commands"
  echo "============================================"
  if [[ "$SHELL" =~ "zsh" ]]; then
    fc -l 1
  else
    history
  fi | awk '{CMD[$2]++} END {for (a in CMD) printf "%-15s %s\n", CMD[a], a}' |
    sort -nr |
    head -n20 |
    nl
  echo "============================================"
}
