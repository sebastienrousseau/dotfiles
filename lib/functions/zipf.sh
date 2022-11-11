#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# zipf: Function to create a ZIP archive of a folder
function zipf() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] Creating the ZIP archive folder $1.zip"
  zip -r "$1".zip "$1"
}
