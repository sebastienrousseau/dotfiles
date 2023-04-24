#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅳🅸🆂🅺 🆄🆂🅰🅶🅴 🅰🅻🅸🅰🆂🅴🆂
if command -v du &>/dev/null; then
  # Display the disk usage of the current directory.
  alias du="du -h"

  # File size of files and directories in current directory.
  alias du1='du -hxd 1 | sort -h'

  # File size of files and directories.
  alias duh='du'

  # Top 10 largest files and directories in current directory.
  alias ducks="du -cks * .*| sort -rn | head -n 10"

  # File size human readable output sorted by size.
  alias dus='du -hs *'

  # File size of files and directories in current directory including symlinks.
  alias dusym="du * -hsLc"

  # Total file size of current directory.
  alias dut='dus'

fi
