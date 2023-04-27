#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# mount_read_only: Function to mount a read-only disk image as read-write
mount_read_only() {
  hdiutil attach "$1" -shadow /tmp/"$1".shadow -noverify
}
