#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Curl HTTP Status Code Viewer (curlstatus)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   curlstatus is a function to fetch and display the HTTP status code for a
#   given URL. It uses curl to make a request and extracts the HTTP status
#   code.
#
# Usage:
#   curlstatus [url]
#   curlstatus --help
#
# Arguments:
#   url         The URL for which to fetch the HTTP status code.
#   --help      Displays this help menu and exits.
#
# Examples:
#   curlstatus https://example.com
#       # Fetch and display the HTTP status code for the given URL.
#
#   curlstatus --help
#       # Displays the help menu.
#
################################################################################

# Function to fetch and display HTTP status code
curlstatus() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "curlstatus: Curl HTTP Status Code Viewer"
    echo
    echo "Usage:"
    echo "  curlstatus [url]"
    echo "  curlstatus --help"
    echo
    echo "Aliases:"
    echo "  alias cs='curlstatus'       # Alias for curlstatus"
    echo "  alias cst='curlstatus'      # Alias for curlstatus"
    echo "  alias httpcode='curlstatus' # Alias for curlstatus"
    echo
    echo "Arguments:"
    echo "  url         The URL for which to fetch the HTTP status code."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  curlstatus https://example.com"
    echo "      # Fetch and display the HTTP status code for the given URL."
    echo
    echo "  curlstatus --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Check if a URL is provided
  if [[ -z "$1" ]]; then
    echo "[ERROR] No URL provided. Use 'curlstatus --help' for usage information." >&2
    return 1
  fi

  # Fetch and display the HTTP status code
  echo "Fetching HTTP status code for URL: $1"
  curl -k -s -o /dev/null -w "%{http_code}" "$1"
  echo
}

# Aliases for convenience
alias cs='curlstatus'       # Alias for curlstatus
alias cst='curlstatus'      # Alias for curlstatus
alias httpcode='curlstatus' # Alias for curlstatus
