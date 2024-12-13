#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
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
