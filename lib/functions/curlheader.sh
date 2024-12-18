#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Curl Header Viewer (curlheader)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   curlheader is a function to fetch and display HTTP headers for a given URL.
#   It can either display all headers or filter for a specific header by name.
#
# Usage:
#   curlheader [header] [url]
#   curlheader --help
#
# Arguments:
#   header    The specific HTTP header to filter and display (optional).
#   url       The URL for which to fetch headers.
#   --help    Displays this help menu and exits.
#
# Examples:
#   curlheader https://example.com
#       # Fetch and display all headers for the given URL.
#
#   curlheader Content-Type https://example.com
#       # Fetch and display only the Content-Type header for the given URL.
#
#   curlheader --help
#       # Displays the help menu.
#
################################################################################

# Function to fetch and display HTTP headers
curlheader() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "curlheader: Curl Header Viewer"
    echo
    echo "Usage:"
    echo "  curlheader [header] [url]"
    echo "  curlheader --help"
    echo
    echo "Arguments:"
    echo "  header    The specific HTTP header to filter and display (optional)."
    echo "  url       The URL for which to fetch headers."
    echo "  --help    Displays this help menu and exits."
    echo
    echo "Aliases:"
    echo "  alias chd='curlheader'  # Alias for curlheader"
    echo "  alias chdr='curlheader' # Alias for curlheader"
    echo
    echo "Examples:"
    echo "  curlheader https://example.com"
    echo "      # Fetch and display all headers for the given URL."
    echo
    echo "  curlheader Content-Type https://example.com"
    echo "      # Fetch and display only the Content-Type header for the given URL."
    echo
    echo "  curlheader --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Check if only a URL is provided
  if [[ -z "$2" ]]; then
    echo "Fetching all headers for URL: $1"
    curl -k -s -D - "$1" -o /dev/null
  else
    # Fetch and filter for a specific header
    echo "Fetching '$1' header for URL: $2"
    curl -k -s -D - "$2" -o /dev/null | grep -i "$1:"
  fi
}

# Aliases for convenience
alias chd='curlheader'  # Alias for curlheader
alias chdr='curlheader' # Alias for curlheader
