#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Password Generator (genpass)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   genpass generates a strong random password with customizable blocks and
#   a separator. Each block is 12 characters by default (high entropy).
#
# Usage:
#   genpass [num_blocks] [separator]
#
# Arguments:
#   num_blocks    Number of blocks to generate (default: 3).
#   separator     Custom separator between blocks (default: '-').
#
# Examples:
#   genpass              # Generates a password with 3 blocks separated by '-'
#   genpass 5 /          # Generates a password with 5 blocks separated by '/'
#   genpass 6 :          # Generates a password with 6 blocks separated by ':'
#
# Clipboard Support:
#   If a clipboard utility is available (pbcopy, xclip, wl-copy, or clip),
#   the password will automatically be copied to the clipboard.
#
################################################################################

genpass() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    cat <<EOF
genpass: Generate a strong random password with customizable blocks and separator

Usage:
  genpass [num_blocks] [separator]

Arguments:
  num_blocks    Number of blocks to generate (default: 3).
  separator     Custom separator between blocks (default: '-').

Examples:
  genpass              # Generates a password with 3 blocks separated by '-'
  genpass 5 /          # Generates a password with 5 blocks separated by '/'
  genpass 6 :          # Generates a password with 6 blocks separated by ':'

Clipboard Support:
  If a clipboard utility is available (pbcopy, xclip, wl-copy, or clip), the password will
  automatically be copied to the clipboard.
EOF
    return 0
  fi

  # Ensure 'openssl' is installed
  if ! command -v openssl &>/dev/null; then
    echo "[ERROR] 'openssl' is required but not installed. Please install it and try again." >&2
    return 1
  fi

  # Default parameters
  local num_blocks="${1:-3}"        # Number of blocks (default: 3)
  local separator="${2:--}"         # Separator between blocks (default: '-')
  local block_size=12               # Length of each block (high-entropy default)

  # Define character set for high entropy
  local CHARSET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+{}|:<>?~[];',./=-"

  # Initialize password variable
  local password=""

  # Generate each block and append to the password
  for ((i = 0; i < num_blocks; i++)); do
    local block=""

    # Generate exactly block_size characters
    while [[ ${#block} -lt $block_size ]]; do
      block+=$(openssl rand -base64 48 | tr -dc "$CHARSET" | head -c $((block_size - ${#block})))
    done

    # Append separator if necessary
    password+="${password:+$separator}$block"
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
