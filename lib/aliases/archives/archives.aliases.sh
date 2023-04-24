#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅰🆁🅲🅷🅸🆅🅴🆂 🅰🅻🅸🅰🆂🅴🆂
if command -v 7z &>/dev/null; then
  # Compress a whole directory (including subdirectories) to a 7z file.
  alias c7z='7z a'
  # Extract a whole directory (including subdirectories) from a 7z file.
  alias e7z='7z x'
fi

if command -v tar &>/dev/null; then
  # Compress a file to a bzip2 file.
  alias cbzip2='tar -cvjf'
  # Compress a whole directory (including subdirectories) to a tar file.
  alias ctar='tar -cvf'
  # Extract a whole directory (including subdirectories) from a tar
  # file.
  alias etar='tar -xvf'
  # Compress a file to a gzip file.
  alias cgzip='tar -zcvf'
  # Compress a whole directory (including subdirectories) to an xz file.
  alias cxz='tar -cvJf'
  # Extract a file from a bzip2 file.
  alias ebzip2='tar -xvjf'
  # Extract a file from a gzip file.
  alias egzip='tar -xvzf'
  # Extract a whole directory (including subdirectories) from an xz
  # file.
  alias exz='tar -xvJf'
fi

if command -v jar &>/dev/null; then
  # Compress a whole directory (including subdirectories) to a jar file.
  alias cjar='jar -cvf'
  # Extract a whole directory (including subdirectories) from a jar
  # file.
  alias ejar='jar -xvf'
fi

if command -v xz &>/dev/null; then
  # Compress a whole directory (including subdirectories) to an xz file.
  alias cxz2='xz -zcvf'
  # Extract a whole directory (including subdirectories) from an xz
  # file.
  alias exz2='xz -zxvf'
fi

if command -v zip &>/dev/null; then
  # Compress a whole directory (including subdirectories) to a zip file.
  alias czip='zip -r'
  # Extract a whole directory (including subdirectories) from a zip
  # file.
  alias ezip='unzip'
fi

if command -v zstd &>/dev/null; then
  # Compress a whole directory (including subdirectories) to a zstd file.
  alias czstd='zstd -zcvf'
  # Extract a whole directory (including subdirectories) from a zstd
  # file.
  alias ezstd='zstd -zxvf'
fi

# Compress a file to a lzma file.
if command -v xz &>/dev/null; then
  alias clzma='xz -zcvf'
  alias elzma='xz -zxvf'
fi

# Compress a file to a z file.
if command -v gzip &>/dev/null; then
  alias czlib='gzip -cv'
  alias ezlib='gzip -dv'
fi

# Compress a file to a bz2 file.
if command -v bzip2 &>/dev/null; then
  alias cbz2='bzip2 -zkvf'
  alias ebz2='bzip2 -dkvf'
fi

# Compress a file to a lzo file.
if command -v lzop &>/dev/null; then
  alias clzo='lzop -cv'
  alias elzo='lzop -dv'
fi

# Compress a file to a lz4 file.
if command -v lz4 &>/dev/null; then
  alias clz4='lz4 -zcv'
  alias elz4='lz4 -dcv'
fi

# Compress a file to a zst file.
if command -v zstd &>/dev/null; then
  alias czst='zstd -zcv'
  alias ezst='zstd -dcv'
fi

# Compress a file to a pigz file.
if command -v pigz &>/dev/null; then
  alias cpgz='pigz -zkvf'
  alias epgz='pigz -dkvf'
fi

# Compress a whole directory (including subdirectories) to a tar.bz2
# file.
if command -v tar &>/dev/null && command -v bzip2 &>/dev/null; then
  alias ctbz2='tar -cvjf'
  alias etbz2='tar -xvjf'
fi

# Compress a whole directory (including subdirectories) to a tar.lzma
# file.
if command -v tar &>/dev/null && command -v xz &>/dev/null; then
  alias ctlzma='tar --lzma -cvf'
  alias etlzma='tar --lzma -xvf'
fi

# Compress a whole directory (including subdirectories) to a tar.gz
# file.
if command -v tar &>/dev/null && command -v gzip &>/dev/null; then
  alias ctgz='tar -zcvf'
  alias etgz='tar -zxvf'
fi

# Compress a whole directory (including subdirectories) to a tar.lzo
# file.
if command -v tar &>/dev/null && command -v lzop &>/dev/null; then
  alias ctlzo='tar --lzip -cvf'
  alias etlzo='tar --lzip -xvf'
fi

# Compress a whole directory (including subdirectories) to a tar.zst
# file.
if command -v tar &>/dev/null && command -v zstd &>/dev/null; then
  alias ctzst='tar --zstd -cvf'
  alias etzst='tar --zstd -xvf'
fi

# Compress a whole directory (including subdirectories) to a tar.pgz
# file.
if command -v tar &>/dev/null && command -v pigz &>/dev/null; then
  alias ctpgz='tar --use-compress-program=pigz -cvf'
  alias etpgz='tar --use-compress-program=pigz -xvf'
fi
