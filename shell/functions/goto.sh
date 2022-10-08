#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.456) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# goto: Function to change to the directory inputed
goto() {
  if [[ -e "$1" ]]; then
    cd "$1" || exit
    l
  else
    echo "[ERROR] Please add a directory name" >&2
  fi
}
