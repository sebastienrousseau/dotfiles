#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Change directory aliases
# Made with ♥ by Sebastien Rousseau
# License: MIT
# This script provides aliases to quickly change directories.
################################################################################

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
alias app="cd ${APP_DIR} && ls -lh --group-directories-first"    # Applications
alias cod="cd ${CODE_DIR} && ls -lh --group-directories-first"   # Code
alias des="cd ${DESK_DIR} && ls -lh --group-directories-first"   # Desktop
alias doc="cd ${DOCS_DIR} && ls -lh --group-directories-first"   # Documents
alias dot="cd ${DOTF_DIR} && ls -lh --group-directories-first"   # Dotfiles
alias dow="cd ${DOWN_DIR} && ls -lh --group-directories-first"   # Downloads
alias hom="cd ${HOME_DIR} && ls -lh --group-directories-first"   # Home Directory
alias mus="cd ${MUSIC_DIR} && ls -lh --group-directories-first"  # Music
alias pic="cd ${PICS_DIR} && ls -lh --group-directories-first"   # Pictures
alias vid="cd ${VIDS_DIR} && ls -lh --group-directories-first"   # Videos

#-----------------------------------------------------------------------------
# System Directories
#-----------------------------------------------------------------------------
[[ -d "/etc" ]] && alias etc="cd /etc && ls -lh --group-directories-first"   # System configuration
[[ -d "/var" ]] && alias var="cd /var && ls -lh --group-directories-first"   # Variable data
[[ -d "/tmp" ]] && alias tmp="cd /tmp && ls -lh --group-directories-first"   # Temporary files
