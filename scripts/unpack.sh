#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.
export DF_DOTFILESDIR              # Exporting Location of dotfiles.

# shellcheck source=/dev/null
. "${DF_DOTFILESDIR}/scripts/constants.sh"

## 🆄🅽🅿🅰🅲🅺 - Unpack the dotfiles on your system.
unpack() {
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Unpacking ${GREEN}Dotfiles v${VERSION}${NC}."

  # shellcheck disable=SC2154
  unzip -qq -u "${DF_DOWNLOADDIR}"/v"${DF_VERSION}".zip -d "${DF_DOWNLOADDIR}"

  # shellcheck disable=SC2154
  mv "${DF_DOWNLOADDIR}/dotfiles-${DF_VERSION}/lib/" "${DF_DOTFILESDIR}"

  # shellcheck disable=SC2154
  rm "${DF_DOWNLOADDIR}/v${DF_VERSION}.zip"
}
