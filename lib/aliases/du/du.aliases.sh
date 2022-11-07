#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅳🅸🆂🅺 🆄🆂🅰🅶🅴 🅰🅻🅸🅰🆂🅴🆂
if command -v 'du' >/dev/null; then
  alias du="du -h"                                  # du: Display the disk usage of the current directory.
  alias du1='du -hxd 1 | sort -h'                   # du1: File size of files and directories in current directory.
  alias ducks="du -cks * .*| sort -rn | head -n 10" # ducks: Top 10 largest files and directories in current directory.
  alias duh='du'                                    # duh: File size of files and directories.
  alias dus='du -hs *'                              # dus: File size human readable output sorted by size.
  alias dusym="du * -hsLc"                          # dusym: File size of files and directories in current directory including symlinks.
  alias dut='dus'                                   # dut: Total file size of current directory.
fi
