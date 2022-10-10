#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.457) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# mount_read_only: Function to mount a read-only disk image as read-write
mount_read_only() {
  hdiutil attach "$1" -shadow /tmp/"$1".shadow -noverify
}
