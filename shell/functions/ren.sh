#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Function to rename files extension.
#
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#

# ren: Function to rename files extension.
ren() {
  for f in *."$1"; do
    mv "$f" "${f%."$1"}.$2"
  done
}
