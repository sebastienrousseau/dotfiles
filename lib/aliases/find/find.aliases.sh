#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT
# Script: find.aliases.sh
# Version: 0.2.470
# Website: https://dotfiles.io

# 🅵🅸🅽🅳 🅰🅻🅸🅰🆂🅴🆂

if command -v fd &>/dev/null; then
  # fd: a simple, fast and user-friendly alternative to find
  # Always colorize output by default.
  alias fd='fd --color always'

  # List all files with absolute path.
  alias fda='fd --absolute-path'

  # List all files with case-insensitive search.
  alias fdc='fd --ignore-case'

  # List all files with details.
  alias fdd='fd --list-details'

  # List all files with extension.
  alias fde='fd --extension'

  # List all files with follow symlinks.
  alias fdf='fd --follow'

  # List all files with help.
  alias fdh='fd --help'

  # List all files, including hidden files.
  alias fdh='fd --hidden'

  # List all files with glob.
  alias fdn='fd --glob'

  # List all files with owner.
  alias fdo='fd --owner'

  # List all files with size.
  alias fds='fd --size'

  # List all files with exclude.
  alias fdu='fd --exclude'

  # List all files with version.
  alias fdv='fd --version'

  # Execute a command for each search result.
  alias fdx='fd --exec'

  # Use fd as a replacement for find.
  alias find='fd'

fi
