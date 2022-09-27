#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Function to combine mkdir and cd.
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#

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