#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.455) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# mcd: Function to combine mkdir and cd.
mcd() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] Creating the folder $1"
  mkdir "$1"
  echo "[INFO] Switching to $1 folder"
  cd "$1" || exit
}

alias mkcd='mcd' # Alias for mcd
