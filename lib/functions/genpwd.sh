#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Password Generator (genpwd)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   genpwd generates a strong random password with customizable length and
#   separator. The user can specify the number of blocks and a separator
#   character. Each block consists of 6 characters (5 alphanumeric + 1 special).
#
# Usage:
#   genpwd [num_blocks] [separator]
#
# Arguments:
#   num_blocks    Number of blocks of 6 characters to generate (default: 3).
#   separator     Custom separator between blocks (default: '-').
#
# Examples:
#   genpwd              # Generates a password with 3 blocks separated by '-'
#   genpwd 5 /          # Generates a password with 5 blocks separated by '/'
#   genpwd 6 :          # Generates a password with 6 blocks separated by ':'
#
# Clipboard Support:
#   If a clipboard utility is available (pbcopy, xclip, wl-copy, or clip), the
#   password will automatically be copied to the clipboard.
#
################################################################################

genpwd() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "genpwd: Generate a strong random password with customizable length and separator"
    echo
    echo "Usage:"
    echo "  genpwd [num_blocks] [separator]"
    echo
    echo "Arguments:"
    echo "  num_blocks    Number of blocks of 6 characters to generate (default: 3)."
    echo "  separator     Custom separator between blocks (default: '-')."
    echo
    echo "Examples:"
    echo "  genpwd              # Generates a password with 3 blocks separated by '-'"
    echo "  genpwd 5 /          # Generates a password with 5 blocks separated by '/'"
    echo "  genpwd 6 :          # Generates a password with 6 blocks separated by ':'"
    echo
    echo "Clipboard Support:"
    echo "  If a clipboard utility is available (pbcopy, xclip, wl-copy, or clip), the password will"
    echo "  automatically be copied to the clipboard."
    echo
    return 0
  fi

  # Check for required tools
  if ! command -v openssl &>/dev/null; then
    echo "[ERROR] 'openssl' is required but not installed. Please install it and try again." >&2
    return 1
  fi

  # Define the number of blocks (default: 3) and separator (default: '-')
  local num_blocks="${1:-3}"        # Number of blocks
  local separator="${2:--}"         # Separator between blocks
  local SPECIAL="!@#$%^&*()+=[]{};':,.?~|<>€¥_"  # Special characters

  # Generate a sufficiently long random alphanumeric base
  local base_password=$(openssl rand -base64 128 | tr -dc '[:alnum:]')

  # Initialize the password variable
  local password=""
  
  # Build the password with the specified number of blocks
  for ((i = 0; i < num_blocks; i++)); do
    # Generate a random 6-character block with special characters
    local block="${base_password:$((i * 6)):5}${SPECIAL:$((RANDOM % ${#SPECIAL})):1}"
    
    # Append the block to the password
    if [[ -n "$password" ]]; then
      password+="${separator}"
    fi
    password+="${block}"
  done

  # Output the password
  echo "[INFO] Generated password: ${password}"

  # Copy to clipboard if possible
  if command -v pbcopy &>/dev/null; then
    echo -n "${password}" | pbcopy
    echo "[INFO] Password copied to clipboard (macOS)."
  elif command -v xclip &>/dev/null; then
    echo -n "${password}" | xclip -selection clipboard
    echo "[INFO] Password copied to clipboard (Linux)."
  elif command -v wl-copy &>/dev/null; then
    echo -n "${password}" | wl-copy
    echo "[INFO] Password copied to clipboard (Linux with Wayland)."
  elif command -v clip &>/dev/null; then
    echo -n "${password}" | clip
    echo "[INFO] Password copied to clipboard (Windows)."
  else
    echo "[WARNING] Clipboard tool not found. Password not copied to clipboard."
  fi

  return 0
}
