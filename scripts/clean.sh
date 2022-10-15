#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles"        # Location of dotfiles.
export DF_DOTFILESDIR="${DF_DOTFILESDIR}" # Exporting Location of dotfiles.

# shellcheck source=/dev/null
. "${DF_DOTFILESDIR}/scripts/constants.sh"

## 🅲🅻🅴🅰🅽 - Clean up.
clean() {
  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Cleaning up installation files."

  # shellcheck disable=SC2154
  rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/bash &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/curl &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/jshint &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/profile &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/tmux &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/vim &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/wget &&
    rm -Rf "${DF_DOTFILESDIR}"/lib/configurations/zsh

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} ${DF_BIGreen}Dotfiles v${DF_VERSION}${DF_NC} has been installed on your system."

  # shellcheck disable=SC2154
  # rm -rfi "${DF_DOTFILESDIR}" &&
  # rm -rfi "${DF_BACKUPDIR}" &&
  rm -rfi "${DF_DOWNLOADDIR}"/dotfiles*
}
