#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅵🅸🅽🅳 🅰🅻🅸🅰🆂🅴🆂
alias fd='fd --color always '  # fd: always colorize output by default.
alias fda='fd --absolute-path' # fda: list all files with absolute path.
alias fdc='fd --ignore-case'   # fdc: list all files with case insensitive search.
alias fdd='fd  --list-details' # fdd: list all files with details.
alias fde='fd --extension'     # fde: list all files with extension.
alias fdf='fd --follow'        # fdf: list all files with follow symlinks.
alias fdh='fd --help'          # fdh: list all files with help.
alias fdh='fd --hidden'        # fdh: list all files with hidden files.
alias fdn='fd --glob'          # fdn: list all files with glob.
alias fdo='fd --owner'         # fdo: list all files with owner.
alias fds='fd --size'          # fds: list all files with size.
alias fdu='fd --exclude'       # fdu: list all files with exclude.
alias fdv='fd --version'       # fdv: list all files with version.
alias fdx='fd --exec'          # fdx: Execute a command for each search result.
alias find='fd'                # find: fd is a simple, fast and user-friendly alternative to find.
