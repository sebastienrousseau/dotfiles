#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Hidden Files Visibility Toggle (hiddenfiles)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   hiddenfiles is a utility function to toggle the visibility of hidden files
#   and system files in the Finder on macOS. By default, it hides hidden files.
#
# Usage:
#   hiddenfiles [show|hide]
#   hiddenfiles --help
#
# Arguments:
#   show        Show hidden files and system files in Finder.
#   hide        Hide hidden files and system files in Finder (default behavior).
#   --help      Displays this help menu and exits.
#
# Examples:
#   hiddenfiles hide
#       # Hides hidden files and system files in Finder.
#
#   hiddenfiles show
#       # Shows hidden files and system files in Finder.
#
#   hiddenfiles --help
#       # Displays the help menu.
#
################################################################################

hiddenfiles() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "hiddenfiles: Hidden Files Visibility Toggle"
    echo
    echo "Usage:"
    echo "  hiddenfiles [show|hide]"
    echo "  hiddenfiles --help"
    echo
    echo "Arguments:"
    echo "  show        Show hidden files and system files in Finder."
    echo "  hide        Hide hidden files and system files in Finder (default behavior)."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  hiddenfiles hide"
    echo "      # Hides hidden files and system files in Finder."
    echo
    echo "  hiddenfiles show"
    echo "      # Shows hidden files and system files in Finder."
    echo
    return 0
  fi

  # Set default action to 'hide' if no argument is provided
  local action="${1:-hide}"

  if [[ "$action" == "hide" ]]; then
    echo "[INFO] Hiding hidden files and system files in Finder..."
    defaults write com.apple.Finder AppleShowAllFiles NO
  elif [[ "$action" == "show" ]]; then
    echo "[INFO] Showing hidden files and system files in Finder..."
    defaults write com.apple.Finder AppleShowAllFiles YES
  else
    echo "[ERROR] Invalid argument: '$1'. Use 'hiddenfiles --help' for usage information." >&2
    return 1
  fi

  # Restart Finder to apply changes
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'

  echo "[INFO] Finder settings updated successfully."
}
