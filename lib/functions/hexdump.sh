#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Hex Dump Viewer (hexdump)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   hexdump is a utility function to display the contents of a file in a
#   hex dump format. By default, it shows the entire file unless a line limit
#   is specified.
#
# Usage:
#   hexdump [file] [lines]
#   hexdump --all
#   hexdump --help
#
# Arguments:
#   file        The file to display in hex dump format.
#   lines       The number of lines to display (optional, default: all lines).
#   --all       Displays the entire file in hex dump format.
#   --help      Displays this help menu and exits.
#
# Examples:
#   hexdump example.txt
#       # Displays the entire file 'example.txt' in hex dump format.
#
#   hexdump example.txt 20
#       # Displays the first 20 lines of the file 'example.txt' in hex dump format.
#
#   hexdump --help
#       # Displays the help menu.
#
################################################################################

hexdump() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "hexdump: Hex Dump Viewer"
    echo
    echo "Usage:"
    echo "  hexdump [file] [lines]"
    echo "  hexdump --all"
    echo "  hexdump --help"
    echo
    echo "Arguments:"
    echo "  file        The file to display in hex dump format."
    echo "  lines       The number of lines to display (optional, default: all lines)."
    echo "  --all       Displays the entire file in hex dump format."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  hexdump example.txt"
    echo "      # Displays the entire file 'example.txt' in hex dump format."
    echo
    echo "  hexdump example.txt 20"
    echo "      # Displays the first 20 lines of the file 'example.txt' in hex dump format."
    echo
    echo "  hexdump --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Check if no arguments are provided
  if [[ -z "$1" ]]; then
    echo "[ERROR] No file provided. Use 'hexdump --help' for usage information." >&2
    return 1
  fi

  # Handle --all option
  if [[ "$1" == "--all" ]]; then
    echo "[ERROR] '--all' requires a file argument. Use 'hexdump file.txt' instead." >&2
    return 1
  fi

  # Check if the file exists
  if [[ ! -f "$1" ]]; then
    echo "[ERROR] '$1' is not a valid file." >&2
    return 1
  fi

  # Detect file type
  echo "[INFO] File type: $(file "$1")"

  # Display hex dump
  if [[ -z "$2" || "$2" == "--all" ]]; then
    # Show the entire file if no line limit or --all is specified
    echo "[INFO] Showing full file in hex dump format:"
    /usr/bin/xxd -u -g 1 "$1"
  else
    # Limit output to the specified number of lines
    echo "[INFO] Showing first $2 lines in hex dump format:"
    /usr/bin/xxd -u -g 1 "$1" | /usr/bin/head -n "$2"
  fi
}
