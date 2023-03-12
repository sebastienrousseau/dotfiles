#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets Find Aliases
# License: MIT
# Script: find.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅵🅸🅽🅳 🅰🅻🅸🅰🆂🅴🆂
if command -v 'fd' >/dev/null; then
  alias fd='fd --color always'        # fd: always colorize output by default.
  alias fda='fd --absolute-path'      # fda: list all files with absolute path.
  alias fdb='fd --base-directory'     # fdb: list all files with a base directory.
  alias fdc='fd --ignore-case'        # fdc: list all files with case insensitive search.
  alias fdd='fd --list-details'       # fdd: list all files with details.
  alias fdD='fd --max-depth'          # fdD: search up to a maximum depth.
  alias fde='fd --extension'          # fde: list all files with extension.
  alias fdf='fd --follow'             # fdf: list all files with follow symlinks.
  alias fdh='fd --hidden'             # fdh: list all files with hidden files.
  alias fdl='fd --follow --type file' # fdl: list all files following symlinks.
  alias fdn='fd --glob'               # fdn: list all files with glob.
  alias fdo='fd --owner'              # fdo: list all files with owner.
  alias fdp='fd --full-path'          # fdp: list all files with the full path.
  alias fdr='fd --type directory'     # fdr: list only directories.
  alias fds='fd --size'               # fds: list all files with size.
  alias fdsy='fd --type symlink'      # fdsy: list only symlinks.
  alias fdt='fd --type'               # fdt: list all files of a specific type.
  alias fdu='fd --exclude'            # fdu: list all files with exclude.
  alias fdv='fd --version'            # fdv: list all files with version.
  alias fdx='fd --exec'               # fdx: Execute a command for each search result.
  alias fdz='fd --size -0'            # fdz: list all files with size of 0 bytes.
  alias find='fd'                     # find: fd is a simple, fast and user-friendly alternative to find.
fi
