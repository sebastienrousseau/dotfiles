#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles"        # Location of dotfiles.
export DF_DOTFILESDIR="${DF_DOTFILESDIR}" # Exporting Location of dotfiles.

# shellcheck source=/dev/null
. "${DF_DOTFILESDIR}/scripts/constants.sh"

## 🅷🅴🅻🅿 🅼🅴🅽🆄 - Display help menu.
help() {
  clear
  cat <<EOF

┌───────────────────────────────────────────┐
│             Dotfiles (v${DF_VERSION})           │
├───────────────────────────────────────────┤
│   Simply designed to fit your shell life. │
└───────────────────────────────────────────┘

USAGE:

  dotfiles [COMMAND]

COMMANDS:

  backup    - Backup existing dotfiles from the '${HOME}' directory
  clean     - Removes any previous setup directories
  copy      - Copy the new dotfiles files to your '${HOME}' directory
  download  - Download the latest Dotfiles (v${DF_VERSION})
  assemble  - Run the full installation process
  unpack    - Unpack the Dotfiles
  help      - Show the help menu

DOCUMENTATION:
  website   - https://dotfiles.io

LICENSE:
  This project is licensed under the MIT License.

EOF
}
