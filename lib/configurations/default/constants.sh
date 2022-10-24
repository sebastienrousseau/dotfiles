#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

## 🅳🅾🆃🅵🅸🅻🅴🆂 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variables.
# DF_CURRENT_DIR=${PWD}                   # Current directory.
DF=".dotfiles/"                           # Dotfiles.
DF_DIR="${HOME}/.dotfiles/"               # Dotfiles directory.
DF_BACKUPDIR="${HOME}/dotfiles_backup/"   # Backup directory.
DF_DOWNLOADDIR="${HOME}/Downloads"        # Download directory.
DF_VERSION="0.2.462"                      # Dotfiles Version number.
DF_TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)" # Timestamp for backup directory.

export DF
export DF_BACKUPDIR
export DF_DIR
export DF_DOWNLOADDIR
export DF_TIMESTAMP
export DF_VERSION

## 🅲🅾🅻🅾🆁🆂 - Set colors.
BLACK="$(tput setaf 0)"               # Black
BLUE="$(tput bold && tput setaf 4)"   # Blue
CYAN="$(tput bold && tput setaf 6)"   # Cyan
GREEN="$(tput bold && tput setaf 2)"  # Green
NC="$(tput sgr0)"                     # No Color
PURPLE="$(tput bold && tput setaf 5)" # Purple
RED="$(tput bold && tput setaf 1)"    # Red
WHITE="$(tput bold && tput setaf 7)"  # White
YELLOW="$(tput bold && tput setaf 3)" # Yellow

export BLACK
export BLUE
export CYAN
export GREEN
export NC
export PURPLE
export RED
export WHITE
export YELLOW
