#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# print: Function to display the argument given
print() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "--- $1"
}
