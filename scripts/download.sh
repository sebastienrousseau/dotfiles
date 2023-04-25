#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.
export DF_DOTFILESDIR              # Exporting Location of dotfiles.

# shellcheck disable=SC1091
. "./lib/configurations/default/constants.sh"

## 🅳🅾🆆🅽🅻🅾🅰🅳 - Download the dotfiles on your system.
download() {
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Downloading ${GREEN}Dotfiles v${DF_VERSION}${NC} on your system at ${GREEN}${DF_DOWNLOADDIR}${NC}..."

  # Download the dotfiles with curl.
  # shellcheck disable=SC2154
  # curl -0 https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${DF_VERSION}".tar.gz -o "${DF_DOWNLOADDIR}"/dotfiles-"${DF_VERSION}".tar.gz

  # Download the dotfiles with wget.
  # shellcheck disable=SC2154
  wget --no-check-certificate --content-disposition https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${DF_VERSION}".zip -O "${DF_DOWNLOADDIR}/v${DF_VERSION}.zip"

}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "download" ]]; then
  echo "$*"
  download
fi
