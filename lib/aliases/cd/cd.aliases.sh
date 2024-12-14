#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Change directory aliases
# Made with ♥ by Sebastien Rousseau
# License: MIT
# This script provides functions and aliases to quickly change directories.
################################################################################

#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------
# Function to change directory with optional listing
change_directory() {
    local path="$1"
    local list_contents="${2:-false}"

    if [[ -d "${path}" ]]; then
        cd "${path}" || { echo "Failed to change to directory: ${path}"; return 1; }
        echo "Changed directory to: ${path}"
        if [[ "${list_contents}" == "true" ]]; then
            ls -lh --group-directories-first
        fi
    else
        echo "Error: Directory '${path}' does not exist."
        return 1
    fi
}

# Add tab completion for custom aliases
_cd_alias_completion() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local dirs=("app" "cod" "des" "doc" "dot" "dow" "mus" "pic" "vid" "etc" "var" "tmp")
    COMPREPLY=($(compgen -W "${dirs[*]}" -- "$cur"))
}
complete -F _cd_alias_completion app cod des doc dot dow mus pic vid etc var tmp

#-----------------------------------------------------------------------------
# Frequently Used Directory Variables
#-----------------------------------------------------------------------------
HOME_DIR="${HOME}"
APP_DIR="${HOME}/Applications"
CODE_DIR="${HOME}/Code"
DESK_DIR="${HOME}/Desktop"
DOCS_DIR="${HOME}/Documents"
DOTF_DIR="${HOME}/.dotfiles"
DOWN_DIR="${HOME}/Downloads"
MUSIC_DIR="${HOME}/Music"
PICS_DIR="${HOME}/Pictures"
VIDS_DIR="${HOME}/Videos"

#-----------------------------------------------------------------------------
# Parent Directory Shortcuts
#-----------------------------------------------------------------------------
alias -- -='cd -'                            # Go to the previous directory
alias ..='cd ..'                             # Go up one level
alias ...='cd ../..'                         # Go up two levels
alias ....='cd ../../..'                     # Go up three levels
alias .....='cd ../../../..'                 # Go up four levels

#-----------------------------------------------------------------------------
# Home and Frequently Used Directories
#-----------------------------------------------------------------------------
alias app='change_directory "${APP_DIR}" true'    # Applications
alias cod='change_directory "${CODE_DIR}" true'   # Code
alias des='change_directory "${DESK_DIR}" true'   # Desktop
alias doc='change_directory "${DOCS_DIR}" true'   # Documents
alias dot='change_directory "${DOTF_DIR}" true'   # Dotfiles
alias dow='change_directory "${DOWN_DIR}" true'   # Downloads
alias hom='change_directory "${HOME_DIR}" true'   # Home Directory
alias mus='change_directory "${MUSIC_DIR}" true'  # Music
alias pic='change_directory "${PICS_DIR}" true'   # Pictures
alias vid='change_directory "${VIDS_DIR}" true'   # Videos

#-----------------------------------------------------------------------------
# System Directories
#-----------------------------------------------------------------------------
if [[ -d "/etc" ]]; then
    alias etc='change_directory "/etc" true'      # System configuration directory
fi

if [[ -d "/var" ]]; then
    alias var='change_directory "/var" true'      # System variable data directory
fi

if [[ -d "/tmp" ]]; then
    alias tmp='change_directory "/tmp" true'      # Temporary files directory
fi

#-----------------------------------------------------------------------------
# Dynamic Features
#-----------------------------------------------------------------------------
# Export the function for use in subshells
export -f change_directory
