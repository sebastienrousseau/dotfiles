#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.

# shellcheck disable=SC1091
# shellcheck source=${HOME}/.dotfiles/lib/scripts/constants.sh
. "${DF_DOTFILESDIR}/scripts/constants.sh"

# shellcheck disable=SC1091
# shellcheck source=${HOME}/.dotfiles/lib/scripts/backup.sh
. "${DF_DOTFILESDIR}/scripts/backup.sh"

# shellcheck disable=SC1091
# shellcheck source=${HOME}/.dotfiles/lib/scripts/download.sh
. "${DF_DOTFILESDIR}/scripts/download.sh"

# shellcheck disable=SC1091
# shellcheck source=${HOME}/.dotfiles/lib/scripts/unpack.sh
. "${DF_DOTFILESDIR}/scripts/unpack.sh"

# shellcheck disable=SC1091
# shellcheck source=${HOME}/.dotfiles/lib/scripts/copy.sh
. "${DF_DOTFILESDIR}/scripts/copy.sh"

## 🅰🆂🆂🅴🅼🅱🅻🅴 - Assemble the dotfiles on your system.
assemble() {

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Preparing the dotfiles on your system."

  backup &&
    download &&
    unpack &&
    copy

}
