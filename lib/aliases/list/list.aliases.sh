#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅻🅸🆂🆃 🅰🅻🅸🅰🆂🅴🆂

# List hidden files.
alias 'l.'='ls -dlhF .* | grep -v "^d"'

# Size, show type, human readable.
alias l='ls -lFh'

# Display one file per line.
alias l1='ls -1'

# All files, show type, human readable.
alias la='ls -lAFh'

# List all files in alphabetical order.
alias labc='ls -lap'

# Count the number of lines in the file.
alias lc='wc -l'

# List files by time, newest first.
alias lct='ls -lcrh'

# Sort by date, oldest first.
alias ld='ls -ltrh'

# List directories only.
alias ldir="ls -l | egrep '^d'"

# List hidden files.
alias ldot="l."

# List files by date, most recent last.
alias left='ls -t -1'

# List files by date, most recent first.
alias right='ls -t -1r'

# List files only.
alias lf="ls -l | egrep -v '^d'"

# Sort by size, largest first.
alias lk='ls -lSrh'

# Long list, show almost all, show type, human readable.
alias ll='la'

# List full path of all files in current directory.
alias lla='ls -l -d $PWD/*'

# locale: List all available locales.
alias locale='locale -a | grep UTF-8'

# List all open ports.
alias lp='sudo lsof -i -T -n'

# Recursive list, show type, human readable.
alias lr='ls -lRh'

# Colorize the output.
alias ls='ls --color'

# Order Files Based on Last Modified Time and size.
alias lS='ls -1FSsh'

# List contents of directories in a tree-like format.
alias lt="tree"

# Sort by date, oldest first.
alias lu='ls -lurh'

# Wide list, show almost all, show type, human readable.
alias lw='ls -xAh'

# Sort by extension.
alias lx='ls | sort -k 1,1 -t .'

# Sort by size, smallest first.
alias lz='ls -lSr'
