#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅳🅾🆃🅵🅸🅻🅴🆂 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variables.
DF_BACKUPDIR="${HOME}/dotfiles_backup" # Backup directory.
DF_DOWNLOADDIR="${HOME}/Downloads"     # Download directory.
DF_VERSION="0.2.459"                   # Dotfiles Version number.

export DF_BACKUPDIR="${DF_BACKUPDIR}"     # Exporting Backup directory.
export DF_DOWNLOADDIR="${DF_DOWNLOADDIR}" # Exporting Download directory.
export DF_VERSION="${DF_VERSION}"         # Exporting Dotfiles Version number.

## 🅲🅾🅻🅾🆁🆂 - Set colors.
BLACK=$(tput setaf 0)               # Black
RED=$(tput bold && tput setaf 1)    # Red
GREEN=$(tput bold && tput setaf 2)  # Green
YELLOW=$(tput bold && tput setaf 3) # Yellow
BLUE=$(tput bold && tput setaf 4)   # Blue
PURPLE=$(tput bold && tput setaf 5) # Purple
CYAN=$(tput bold && tput setaf 6)   # Cyan
WHITE=$(tput bold && tput setaf 7)  # White
NC=$(tput sgr0)                     # No Color

export BLACK="${BLACK}"   # Exporting Black.
export RED="${RED}"       # Exporting Red.
export GREEN="${GREEN}"   # Exporting Green.
export YELLOW="${YELLOW}" # Exporting Yellow.
export BLUE="${BLUE}"     # Exporting Blue.
export PURPLE="${PURPLE}" # Exporting Purple.
export CYAN="${CYAN}"     # Exporting Cyan.
export WHITE="${WHITE}"   # Exporting White.
export NC="${NC}"         # Exporting No Color.
