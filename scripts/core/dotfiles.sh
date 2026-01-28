#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.477) - <https://dotfiles.io>
# Made With ❤️ in London, United Kingdom
# Designed by Sebastien Rousseau
# Copyright (c) 2015-2026. All rights reserved.
# License: MIT

## 🅸🅼🅿🅾🆁🆃🆂 - Importing constants and functions.

# shellcheck disable=SC1090,SC1091
CONSTANTS_FILE="./lib/configurations/default/constants.sh"
if [[ -f "$CONSTANTS_FILE" ]]; then
  source "$CONSTANTS_FILE"
else
  # Define fallback constants
  DOTFILES_VERSION="${DOTFILES_VERSION:-0.2.477}"
fi

## 🅼🅰🅸🅽 - Main function.

if [[ "$1" = "backup" ]]; then
  # shellcheck disable=SC2154
  echo "${RED}${NC} Backing up.${NC}"
  . "./scripts/core/backup.sh" &&
    echo "${RED}${NC} Backup completed.${NC}"

elif [[ "$1" = "clean" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}${NC} Removes any previous setup directories.${NC}"
  . "./scripts/core/clean.sh" &&
    clean

elif [[ "$1" = "copy" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}${NC} Copying dotfiles.${NC}"
  . "./scripts/core/copy.sh" &&
    echo "${RED}${NC} Copying completed.${NC}"

elif [[ "$1" = "download" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}${NC} Downloading ${GREEN}Dotfiles v${DF_VERSION}${NC}."
  . "./scripts/core/download.sh" &&
    echo "${RED}${NC} Download completed.${NC}"

elif [[ "$1" = "help" ]]; then
  . "./scripts/core/help.sh" &&
    echo "${RED}${NC} Help menu.${NC}"

elif [[ "$1" = "assemble" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}${NC} Installing ${GREEN}Dotfiles v${VERSION}${NC}."
  . "./scripts/core/assemble.sh" &&
    echo "${RED}${NC} Installation completed.${NC}"

elif [[ "$1" = "unpack" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}${NC} Unpacking ${GREEN}Dotfiles v${DF_VERSION}${NC}."
  . "./scripts/core/unpack.sh" &&
    echo "${RED}${NC} Unpacking completed.${NC}"

else
  . "./scripts/core/help.sh" &&
    echo "${RED}${NC} Help menu.${NC}"
fi
