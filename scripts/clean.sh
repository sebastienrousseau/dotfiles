#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.467) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🅲🅻🅴🅰🅽 - Clean up.
clean() {

  # shellcheck disable=SC1091
  . "./lib/configurations/default/constants.sh"

  echo ""
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Starting Cleanup."
  echo ""

  # shellcheck disable=SC2154
  echo "${GREEN}  ✔${NC} Cleaning up installation files."
  rm -fr dist/
  rm -f tsconfig.tsbuildinfo

}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "clean" ]]; then
  echo "$*"
  clean
fi
