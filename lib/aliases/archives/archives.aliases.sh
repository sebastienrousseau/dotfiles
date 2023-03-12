#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets aliases for archives.
# License: MIT
# Script: archives.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅰🆁🅲🅷🅸🆅🅴🆂 🅰🅻🅸🅰🆂🅴🆂
if command -v '7z' >/dev/null; then
  alias c7z='7z a' # c7z: Compress a whole directory (including subdirectories) to a 7z file.
  alias e7z='7z x' # e7z: Extract a whole directory (including subdirectories) from a 7z file.
  alias l7z='7z l' # l7z: List contents of a 7z archive.
  alias t7z='7z t' # t7z: Test integrity of a 7z archive.
  alias x7z='7z x' # x7z: Extract files with full paths from a 7z archive.
fi

if command -v 'bzip2' >/dev/null; then
  alias cbz2='tar -cvjf' # cbz2: Compress a file to a bz2 file.
  alias ebz2='tar -xvjf' # ebz2: Extract a file from a bz2 file.
fi

if command -v 'gzip' >/dev/null; then
  alias cgz='tar -zcvf' # cgz: Compress a file to a gz file.
  alias egz='tar -xvzf' # egz: Extract a file from a gz file.
fi

if command -v 'jar' >/dev/null; then
  alias cjar='jar -cvf' # cjar: Compress a whole directory (including subdirectories) to a jar file.
  alias ejar='jar -xvf' # ejar: Extract a whole directory (including subdirectories) from a jar file.
fi

if command -v 'lzma' >/dev/null; then
  alias clzma='xz -zcvf' # clzma: Compress a file to a lzma file.
  alias elzma='xz -zxvf' # elzma: Extract a file from a lzma file.
fi

if command -v 'rar' >/dev/null; then
  alias crar='rar a' # crar: Compress a file to a rar file.
  alias erar='rar x' # erar: Extract a file from a rar file.
fi

if command -v 'tar' >/dev/null; then
  alias ctar='tar -cvf'           # ctar: Compress a whole directory (including subdirectories) to a tar file.
  alias etar='tar -xvf'           # etar: Extract a whole directory (including subdirectories) from a tar file.
  alias t7z='tar -cvf'            # t7z: Compress a whole directory (including subdirectories) to a 7z file.
  alias tbz='tar -cvjf'           # tbz: Compress a whole directory (including subdirectories) to a bzip2 file.
  alias tgz='tar -cvzf'           # tgz: Compress a whole directory (including subdirectories) to a tar.gz file.
  alias txz='tar -cJf'            # txz: Compress a whole directory (including subdirectories) to a xz file.
  alias txzstd='tar -c --zstd -f' # txzstd: Compress a whole directory (including subdirectories) to a zstd file.
  alias tz='tar -cvzf'            # tz: Compress a whole directory (including subdirectories) to a gzip file.
  alias unzip='tar -xvzf'         # unzip: Extract a whole directory (including subdirectories) from a zip file.
  alias x7z='tar -xvf'            # x7z: Extract a whole directory (including subdirectories) from a 7z file.
  alias xbz='tar -xvjf'           # xbz: Extract a whole directory (including subdirectories) from a bzip2 file.
  alias xgz='tar -xvzf'           # xgz: Extract a whole directory (including subdirectories) from a tar.gz file.
  alias xxz='tar -xvJf'           # xxz: Extract a whole directory (including subdirectories) from a xz file.
  alias xxzstd='tar -x --zstd -f' # xxzstd: Extract a whole directory (including subdirectories) from a zstd file.
  alias xz='tar -xvzf'            # xz: Extract a whole directory (including subdirectories) from a gzip file.
  alias zip='tar -cvzf'           # zip: Compress a whole directory (including subdirectories) to a zip file.
fi

if command -v 'xz' >/dev/null; then
  alias cxz='xz -zcvf' # cxz: Compress a whole directory (including subdirectories) to a xz file.
  alias exz='xz -zxvf' # exz: Extract a whole directory (including subdirectories) from a xz file.
  alias tlz='tar -cJf' # tlz: Compress a whole directory (including subdirectories) to a lz file.
  alias xlz='tar -xvf' # xlz: Extract a whole directory (including subdirectories) from a lz file.
fi

if command -v 'zip' >/dev/null; then
  alias cz='zip -r'     # cz: Compress a whole directory (including subdirectories) to a zip file.
  alias ez='unzip'      # ez: Extract a whole directory (including subdirectories) from a zip file.
  alias tbz='tar -cvjf' # tbz: Compress a whole directory (including subdirectories) to a bzip2 file.
  alias txz='tar -cJf'  # txz: Compress a whole directory (including subdirectories) to a xz file.
  alias tz='tar -cvzf'  # tz: Compress a whole directory (including subdirectories) to a gzip file.
  alias xbz='tar -xvjf' # xbz: Extract a whole directory (including subdirectories) from a bzip2 file.
  alias xxz='tar -xvJf' # xxz: Extract a whole directory (including subdirectories) from a xz file.
  alias xz='tar -xvzf'  # xz: Extract a whole directory (including subdirectories) from a gzip file.
fi

if command -v 'zstd' >/dev/null; then
  alias czstd='zstd -zcvf'       # czstd: Compress a whole directory (including subdirectories) to a zstd file.
  alias ezstd='zstd -zxvf'       # ezstd: Extract a whole directory (including subdirectories) from a zstd file.
  alias tzstd='tar -I zstd -cvf' # tzstd: Compress a whole directory (including subdirectories) to a tar.zst file.
  alias xzstd='tar -I zstd -xvf' # xzstd: Extract a whole directory (including subdirectories) from a tar.zst file.
fi
