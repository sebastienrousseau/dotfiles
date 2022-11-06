#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

## 🅸🅼🅿🅾🆁🆃🆂 - Importing constants and functions.

# shellcheck disable=SC1091
. "./lib/configurations/default/constants.sh"

## 🅼🅰🅸🅽 - Main function.

if [[ "$1" = "backup" ]]; then
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Backing up.${NC}"
  . "./scripts/backup.sh" &&
    echo "${RED}❭${NC} Backup completed.${NC}"

elif [[ "$1" = "clean" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Removes any previous setup directories.${NC}"
  . "./scripts/clean.sh" &&
    clean

elif [[ "$1" = "copy" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Copying dotfiles.${NC}"
  . "./scripts/copy.sh" &&
    echo "${RED}❭${NC} Copying completed.${NC}"

elif [[ "$1" = "download" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Downloading ${GREEN}Dotfiles v${DF_VERSION}${NC}."
  . "./scripts/download.sh" &&
    echo "${RED}❭${NC} Download completed.${NC}"

elif [[ "$1" = "help" ]]; then
  . "./scripts/help.sh" &&
    echo "${RED}❭${NC} Help menu.${NC}"

elif [[ "$1" = "assemble" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Installing ${GREEN}Dotfiles v${VERSION}${NC}."
  . "./scripts/assemble.sh" &&
    echo "${RED}❭${NC} Installation completed.${NC}"

elif [[ "$1" = "unpack" ]]; then

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Unpacking ${GREEN}Dotfiles v${DF_VERSION}${NC}."
  . "./scripts/unpack.sh" &&
    echo "${RED}❭${NC} Unpacking completed.${NC}"

else
  . "./scripts/help.sh" &&
    echo "${RED}❭${NC} Help menu.${NC}"
fi
