#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Author: Sebastien Rousseau
# Copyright: 2015-2024. All rights reserved
# Description: Enhanced `cd` command aliases with checks, functions, and customization.
# License: MIT
# Script: cd.aliases.sh
# Version: 0.2.469
# Website: https://dotfiles.io

# Usage:
#   Customize directory paths via variables and use aliases to navigate.
#   Example: `cod` to go to the Code directory, `..` to go up one directory.

# Configuration
DOC_DIR="${HOME}/Documents"
VID_DIR="${HOME}/Videos"
# Add more configurable paths here

# Check if directory exists and change to it, listing contents optionally
change_directory() {
  local path="$1"

  if [[ -d "${path}" ]]; then
    cd "${path}" || exit # Exit if cd fails
  else
    echo "Directory '${path}' does not exist."
  fi
}

# Parent Directory Shortcuts
alias -- -='cd -'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Home Directory Shortcut
alias hom='change_directory "${HOME}" true'

# Frequently Used Directories
alias doc='change_directory "$DOC_DIR" true' # Documents
alias vid='change_directory "$VID_DIR" true' # Videos
# Define more aliases like the above for other directories

# System Directories (consider checks for system-specific paths)
alias etc='change_directory "/etc" true'
alias var='change_directory "/var" true'
alias tmp='change_directory "/tmp" true'

# Frequently Used Directories with Improved Error Handling and Customization
APP_DIR="${HOME}/Applications"
CODE_DIR="${HOME}/Code"
DESK_DIR="${HOME}/Desktop"
DOCS_DIR="${HOME}/Documents"
DOTF_DIR="${HOME}/.dotfiles"
DOWN_DIR="${HOME}/Downloads"
MUSIC_DIR="${HOME}/Music"
PICS_DIR="${HOME}/Pictures"
VIDS_DIR="${HOME}/Videos"

# Define functions for each alias with checks and optional ls
alias app='change_directory "$APP_DIR" true' # Applications
alias cod='change_directory "$CODE_DIR" true' # Code
alias des='change_directory "$DESK_DIR" true' # Desktop
alias doc='change_directory "$DOCS_DIR" true' # Documents
alias dot='change_directory "$DOTF_DIR" true' # Dotfiles
alias dow='change_directory "$DOWN_DIR" true' # Downloads
alias mus='change_directory "$MUSIC_DIR" true' # Music
alias pic='change_directory "$PICS_DIR" true' # Pictures
alias vid='change_directory "$VIDS_DIR" true' # Videos
