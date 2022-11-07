#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅰🆁🅲🅷🅸🆅🅴🆂 🅰🅻🅸🅰🆂🅴🆂
if command -v '7z' >/dev/null; then
  alias c7z='7z a' # c7z: Compress a whole directory (including subdirectories) to a 7z file.
  alias e7z='7z x' # e7z: Extract a whole directory (including subdirectories) from a 7z file.
fi

if command -v 'tar' >/dev/null; then
  alias cbz2='tar -cvjf' # cbz2: Compress a file to a bz2 file.
  alias ctar='tar -cvf'  # ctar: Compress a whole directory (including subdirectories) to a tar file.
  alias etar='tar -xvf'  # etar: Extract a whole directory (including subdirectories) from a tar file.
  alias cgz='tar -zcvf'  # cgz: Compress a file to a gz file.
  alias cxz='tar -cvJf'  # cxz: Compress a whole directory (including subdirectories) to a xz file.
  alias ebz2='tar -xvjf' # ebz2: Extract a file from a bz2 file.
  alias egz='tar -xvzf'  # egz: Extract a file from a gz file.
  alias exz='tar -xvJf'  # exz: Extract a whole directory (including subdirectories) from a xz file.
fi

if command -v 'jar' >/dev/null; then
  alias cjar='jar -cvf' # cjar: Compress a whole directory (including subdirectories) to a jar file.
  alias ejar='jar -xvf' # ejar: Extract a whole directory (including subdirectories) from a jar file.
fi

if command -v 'xz' >/dev/null; then
  alias cxz='xz -zcvf' # cxz: Compress a whole directory (including subdirectories) to a xz file.
  alias exz='xz -zxvf' # exz: Extract a whole directory (including subdirectories) from a xz file.
fi

if command -v 'zip' >/dev/null; then
  alias cz='zip -r' # czip: Compress a whole directory (including subdirectories) to a zip file.
  alias ez='unzip'  # ezip: Extract a whole directory (including subdirectories) from a zip file.
fi

if command -v 'zstd' >/dev/null; then
  alias czstd='zstd -zcvf' # czstd: Compress a whole directory (including subdirectories) to a zstd file.
  alias ezstd='zstd -zxvf' # ezstd: Extract a whole directory (including subdirectories) from a zstd file.
fi
