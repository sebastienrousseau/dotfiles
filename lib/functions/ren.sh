#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

# ren: Function to rename files extension.
ren() {
  for f in *."$1"; do
    mv "${f}" "${f%."$1"}.$2"
  done
}
