#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.474) - <https://dotfiles.io>
# Made with  in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

## 🅲🅾🅼🅿🅸🅻🅴 🅳🅾🆃🅵🅸🅻🅴🆂 - Compile dotfiles.

compile() {

  # shellcheck disable=SC1091
  . "./lib/configurations/default/constants.sh"

  echo ""
  # shellcheck disable=SC2154
  echo "${RED}${NC} Starting Compilation."
  echo ""

  echo "${GREEN}  ${NC} Copying libraries."
  # shellcheck disable=SC1091
  cp -R ./lib ./dist/

  echo "${GREEN}  ${NC} Copying scripts."
  # shellcheck disable=SC1091
  cp -R ./scripts ./dist/

  echo "${GREEN}  ${NC} Removing temporary files."
  # shellcheck disable=SC1091
  rimraf \"./dist/lib/**/*.tmp\"

  echo "${GREEN}  ${NC} Copying JavaScript binaries."
  cp -f -R ./bin ./dist/

  echo "${GREEN}  ${NC} Copying Makefile."
  cp -f ./Makefile ./dist

  echo "${GREEN}  ${NC} Compressing JavaScript files."
  jsmin ./bin/backup.js >dist/bin/backup.js && jsmin ./bin/constants.js >dist/bin/constants.js && jsmin ./bin/copy.js >dist/bin/copy.js && jsmin ./bin/dotfiles.js >dist/bin/dotfiles.js && jsmin ./bin/download.js >dist/bin/download.js && jsmin ./bin/index.js >dist/bin/index.js && jsmin ./bin/transfer.js >dist/bin/transfer.js && jsmin ./bin/unpack.js >dist/bin/unpack.js

  echo "${GREEN}  ${NC} Determining the file sizes."
  filesizes ./dist/ >./dist/filesizes.txt

  # shellcheck disable=SC2154
  echo "${GREEN}  ${NC} Compilation completed."
  echo ""
}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "compile" ]]; then
  echo "$*"
  compile
fi
