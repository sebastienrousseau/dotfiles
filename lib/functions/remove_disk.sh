#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# remove_disk: spin down unneeded disk
remove_disk() {
  diskutil eject "$1"
}
