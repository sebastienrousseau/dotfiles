#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# zipf: Function to create a ZIP archive of a folder
function zipf() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] Creating the ZIP archive folder $1.zip"
  zip -r "$1".zip "$1";
}