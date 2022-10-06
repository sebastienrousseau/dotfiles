#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.454) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# ren: Function to rename files extension.
ren() {
  for f in *."$1"; do
    mv "${f}" "${f%."$1"}.$2"
  done
}
