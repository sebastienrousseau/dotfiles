#!/bin/zsh
#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# mount_read_only: Function to mount a read-only disk image as read-write
function mount_read_only() {
  hdiutil attach "$1" -shadow /tmp/"$1".shadow -noverify
}
