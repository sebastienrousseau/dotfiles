#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅸🅽🆃🅴🆁🅰🅲🆃🅸🆅🅴 🅰🅻🅸🅰🆂🅴🆂

# File manipulation aliases

# cp: Copy files and directories interactively (ask before overwrite) with verbose output.
alias cp="cp -vi"

# del: Remove files or directories interactively (ask before each removal) with verbose output, recursively.
alias del="rm -rfvi"

# ln: Create symbolic links interactively (ask before overwrite) with verbose output.
alias ln='ln -vi'

# mv: Move or rename files interactively (ask before overwrite) with verbose output.
alias mv='mv -vi'

# rm: Remove files or directories interactively (ask before each removal) with verbose output.
alias rm='rm -vi'

# zap: Alias for 'rm', removes files or directories interactively (ask before each removal) with verbose output.
alias zap='rm -vi'

# Trash manipulation alias

# bin: Remove all files in the trash directory (user's .Trash) forcefully and recursively.
alias bin='rm -fr ${HOME}/.Trash'

# Other interactive aliases

# chmod: Change file or directory permissions with verbose output.
alias chmod='chmod -v'

# chown: Change file or directory owner and group with verbose output.
alias chown='chown -v'

# diff: Compare and show differences between two files in unified format.
alias diff='diff -u'

# grep: Search for a pattern in files or output, showing line numbers and case-insensitively.
alias grep='grep -n -i'

# mkdir: Create a new directory, making parent directories as needed, with verbose output.
alias mkdir='mkdir -pv'
