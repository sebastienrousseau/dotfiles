#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.475) - <https://dotfiles.io>
# Made With ❤️ in London, United Kingdom
# Designed by Sebastien Rousseau
# Copyright (c) 2015-2026. All rights reserved.
# License: MIT

# shellcheck disable=SC1091
. "./lib/configurations/default/constants.sh"

# shellcheck disable=SC1091
. "./scripts/core/backup.sh"

# shellcheck disable=SC1091
. "./scripts/core/download.sh"

# shellcheck disable=SC1091
. "./scripts/core/unpack.sh"

# shellcheck disable=SC1091
. "./scripts/core/copy.sh"

## 🅱🆄🅸🅻🅳 - Build the dotfiles on your system.
build() {

  # shellcheck disable=SC2154
  echo "${RED}${NC} Preparing the dotfiles on your system."

  backup &&
    download &&
    unpack &&
    copy

}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "build" ]]; then
  echo "$*"
  build
fi
