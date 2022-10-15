#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.

# shellcheck disable=SC1091
. "${DF_DOTFILESDIR}/scripts/constants.sh"

# shellcheck disable=SC1091
. "${DF_DOTFILESDIR}/scripts/backup.sh"

# shellcheck disable=SC1091
. "${DF_DOTFILESDIR}/scripts/download.sh"

# shellcheck disable=SC1091
. "${DF_DOTFILESDIR}/scripts/unpack.sh"

# shellcheck disable=SC1091
. "${DF_DOTFILESDIR}/scripts/copy.sh"

## 🅰🆂🆂🅴🅼🅱🅻🅴 - Assemble the dotfiles on your system.
assemble() {

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Preparing the dotfiles on your system."

  backup &&
    download &&
    unpack &&
    copy

}
