#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.
export DF_DOTFILESDIR              # Exporting Location of dotfiles.

# shellcheck source=/dev/null
. "${DF_DOTFILESDIR}/scripts/constants.sh"

## 🅳🅾🆆🅽🅻🅾🅰🅳 - Download the dotfiles on your system.
download() {
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Downloading ${GREEN}Dotfiles v${DF_VERSION}${NC} on your system."

  # shellcheck disable=SC2154
  # wget https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${DF_VERSION}".zip -N -O "${DF_DOWNLOADDIR}/v${DF_VERSION}.zip"

  # shellcheck disable=SC2154
  curl https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${DF_VERSION}".zip -o "${DF_DOWNLOADDIR}"/v"${DF_VERSION}".zip
}
