#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.467) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.
export DF_DOTFILESDIR              # Exporting Location of dotfiles.

# shellcheck disable=SC1091
. "./lib/configurations/default/constants.sh"

echo ""
# shellcheck disable=SC2154
echo "${RED}❭${NC} Starting help menu."
echo ""

## 🅷🅴🅻🅿 🅼🅴🅽🆄 - Display help menu.
help() {

  # shellcheck disable=SC1091
  . "./scripts/banner.sh"

  cat <<EOF
USAGE:

  pnpm run $(echo -e "\033[1;96m[COMMAND]\033[0m\n")

COMMANDS:

  $(echo -e "\033[1;96mbackup\033[0m\n")   - Backup your current dotfiles.
  $(echo -e "\033[1;96mclean\033[0m\n")    - Removes any previous setup.
  $(echo -e "\033[1;96mcopy\033[0m\n")     - Copy the dotfiles on your system.
  $(echo -e "\033[1;96mdownload\033[0m\n") - Download the dotfiles on your system.
  $(echo -e "\033[1;96mbuild\033[0m\n")    - Run the full installation process.
  $(echo -e "\033[1;96munpack\033[0m\n")   - Extract the dotfiles to your system.
  $(echo -e "\033[1;96mhelp\033[0m\n")     - Display the help menu.

DOCUMENTATION:

  $(echo -e "\033[4;36mhttps://dotfiles.io\033[0m\n")

LICENSE:

  This project is licensed under the MIT License.

EOF
}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "help" ]]; then
  echo "$*"
  help
fi
