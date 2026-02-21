# shellcheck shell=bash
# Copyright (c) 2015-2026. All rights reserved.
# Website: https://dotfiles.io
# License: MIT

# 🅳🅸🆂🅺 🆄🆂🅰🅶🅴 🅰🅻🅸🅰🆂🅴🆂

if command -v 'du' >/dev/null; then

  # Display the disk usage of the current directory.
  alias du="du -h"

  # File size of files and directories in current directory.
  dot_du1() {
    if command -v dust >/dev/null 2>&1; then
      dust -d 1 "$@"
    else
      du -hxd 1 "$@" | sort -h
    fi
  }
  alias du1='dot_du1'

  # Top 10 largest files and directories in current directory.
  alias ducks="du -cks * .* | sort -rn | head -n 10"

  # File size of files and directories.
  alias duh='du'

  # File size human readable output sorted by size.
  alias dus='du -hs *'

  # File size of files and directories in current directory including
  # symlinks.
  alias dusym="du * -hsLc"

  # Total file size of current directory.
  alias dut='dus'

fi
