#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Base64 Encode and Decode (encode64/decode64)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   encode64 and decode64 are functions for encoding and decoding strings to and
#   from base64. These functions can process input either directly as arguments
#   or via standard input (pipe).
#
# Usage:
#   encode64 [string]
#   encode64 --help
#
#   decode64 [base64_string]
#   decode64 --help
#
# Arguments:
#   string             The string to encode into base64 (optional).
#   base64_string      The base64-encoded string to decode (optional).
#   --help             Displays the help menu and exits.
#
# Examples:
#   echo "Hello World" | encode64
#       # Encodes "Hello World" to base64 via pipe.
#
#   encode64 "Hello World"
#       # Encodes "Hello World" to base64 directly from arguments.
#
#   decode64 "SGVsbG8gV29ybGQK"
#       # Decodes the given base64 string to plaintext.
#
################################################################################

# Function to encode a string to base64
encode64() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "encode64: Encode a string to base64"
    echo
    echo "Usage:"
    echo "  encode64 [string]"
    echo "  encode64 --help"
    echo
    echo "Arguments:"
    echo "  string     The string to encode into base64 (optional)."
    echo "  --help     Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  echo \"Hello World\" | encode64"
    echo "      # Encodes \"Hello World\" to base64 via pipe."
    echo
    echo "  encode64 \"Hello World\""
    echo "      # Encodes \"Hello World\" to base64 directly from arguments."
    echo
    return 0
  fi

  # Encode input to base64
  if [[ $# -eq 0 ]]; then
    # Process input from stdin
    cat | base64
  else
    # Process input from arguments
    printf '%s' "$1" | base64
  fi
}

# Function to decode a base64 string
decode64() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "decode64: Decode a base64-encoded string"
    echo
    echo "Usage:"
    echo "  decode64 [base64_string]"
    echo "  decode64 --help"
    echo
    echo "Arguments:"
    echo "  base64_string  The base64-encoded string to decode (optional)."
    echo "  --help         Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  echo \"SGVsbG8gV29ybGQK\" | decode64"
    echo "      # Decodes the base64 string via pipe."
    echo
    echo "  decode64 \"SGVsbG8gV29ybGQK\""
    echo "      # Decodes the given base64 string to plaintext."
    echo
    return 0
  fi

  # Decode input from base64
  if [[ $# -eq 0 ]]; then
    # Process input from stdin
    cat | base64 --decode
  else
    # Process input from arguments
    printf '%s\n' "$1" | base64 --decode
  fi
}

# Aliases for convenience
alias e64=encode64 # Encode to base64.
alias d64=decode64 # Decode from base64.
