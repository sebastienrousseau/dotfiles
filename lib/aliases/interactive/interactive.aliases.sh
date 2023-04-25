#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅸🅽🆃🅴🆁🅰🅲🆃🅸🆅🅴 🅰🅻🅸🅰🆂🅴🆂

# File manipulation aliases

# cp: Copy files and directories.
alias cp="cp -vi"

# del: Remove a file or directory.
alias del="rm -rfvi"

# ln: interactive symbolic link
alias ln='ln -vi'

# mv: Move files interactively (ask before overwrite) and verbose.
alias mv='mv -vi'

# rm: Prompts for every file before removing.
alias rm='rm -vi'

# zap: Remove files interactively (ask before overwrite).
alias zap='rm -vi'

# Trash manipulation alias

# bin: Remove all files in the trash.
alias bin='rm -fr ${HOME}/.Trash'

# Other interactive aliases

# chmod: Change permissions of a file or directory.
alias chmod='chmod -v'

# chown: Change the owner and group of a file or directory.
alias chown='chown -v'

# diff: Compare two files and show the differences.
alias diff='diff -u'

# grep: Search for a pattern in a file or output.
alias grep='grep -n -i'

# mkdir: Create a new directory and display a message on success.
alias mkdir='mkdir -pv'

# touch: Create a new file and display a message on success.
alias touch='touch -v'
