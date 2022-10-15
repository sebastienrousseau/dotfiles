#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅸🅼🅿🅾🆁🆃🆂 - Importing constants and functions.

# shellcheck disable=SC1091
. "./scripts/constants.sh"

## 🅼🅰🅸🅽 - Main function.

if [[ "$1" = "backup" ]]; then

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Backing up.${DF_NC}"
  . "./scripts/backup.sh" &&
    echo "${DF_BIRed}❭${DF_NC} Backup completed.${DF_NC}"

elif [[ "$1" = "clean" ]]; then

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Removes any previous setup directories.${DF_NC}"
  . "./scripts/clean.sh" &&
    clean

elif [[ "$1" = "copy" ]]; then

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Copying dotfiles.${DF_NC}"
  . "./scripts/copy.sh" &&
    copy

elif [[ "$1" = "download" ]]; then

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Downloading ${DF_BIGreen}Dotfiles v${DF_VERSION}${DF_NC}."
  . "./scripts/download.sh" &&
    download

elif [[ "$1" = "help" ]]; then
  . "./scripts/help.sh" &&
    help

elif [[ "$1" = "assemble" ]]; then

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Installing ${DF_BIGreen}Dotfiles v${VERSION}${DF_NC}."
  . "./scripts/assemble.sh" &&
    assemble

elif [[ "$1" = "unpack" ]]; then

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Unpacking ${DF_BIGreen}Dotfiles v${DF_VERSION}${DF_NC}."
  . "./scripts/unpack.sh" &&
    unpack

else
  . "./scripts/help.sh" &&
    help
fi
