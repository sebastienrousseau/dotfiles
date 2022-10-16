#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# shellcheck disable=SC1091
. "./lib/configurations/default/constants.sh"

# shellcheck disable=SC1091
. "./scripts/backup.sh"

# shellcheck disable=SC1091
. "./scripts/download.sh"

# shellcheck disable=SC1091
. "./scripts/unpack.sh"

# shellcheck disable=SC1091
. "./scripts/copy.sh"

## 🅰🆂🆂🅴🅼🅱🅻🅴 - Assemble the dotfiles on your system.
assemble() {

  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Preparing the dotfiles on your system."

  backup &&
    download &&
    unpack &&
    copy

}
