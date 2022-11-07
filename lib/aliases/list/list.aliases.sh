#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅻🅸🆂🆃 🅰🅻🅸🅰🆂🅴🆂
if command -v 'ls' >/dev/null; then
  alias 'l.'='ls -dlhF .* | grep -v "^d"' # l.: List hidden files.
  alias l='ls -lFh'                       # l: Size, show type, human readable.
  alias l1='ls -1'                        # l1: Display one file per line.
  alias la='ls -lAFh'                     # la: All files, show type, human readable.
  alias labc='ls -lap'                    # labc: List all files in alphabetical order.
  alias lc='wc -l'                        # lc: Count the number of lines in the file.
  alias lct='ls -lcrh'                    # lct: List files by time, newest first.
  alias ld='ls -ltrh'                     # lt: Sort by date, oldest first.
  alias ldir="ls -l | egrep '^d'"         # ldir: List directories only.
  alias ldot="l."                         # l.: List hidden files.
  alias left='ls -t -1'                   # left: List files by date, most recent last.
  alias right='ls -t -1r'                 # right: List files by date, most recent first.
  alias lf="ls -l | egrep -v '^d'"        # lf: List files only.
  alias lk='ls -lSrh'                     # lk: Sort by size, largest first.
  alias ll='la'                           # ll: Long list, show almost all, show type, human readable.
  alias lla='ls -l -d $PWD/*'             # lla: List full path of all files in current directory.
  alias locale='locale -a | grep UTF-8'   # locale: List all available locales.
  alias lp='sudo lsof -i -T -n'           # lp: List all open ports.
  alias lr='ls -lRh'                      # lr: Recursive list, show type, human readable.
  alias ls='ls --color'                   # ls: Colorize the output.
  alias lS='ls -1FSsh'                    # lS: Order Files Based on Last Modified Time and size.
  alias lt="tree"                         # lt: List contents of directories in a tree-like format.
  alias lu='ls -lurh'                     # lu: Sort by date, oldest first.
  alias lw='ls -xAh'                      # lw: Wide list, show almost all, show type, human readable.
  alias lx='ls | sort -k 1,1 -t .'        # lx: Sort by extension.
  alias lz='ls -lSr'                      # lz: Sort by size, smallest first.
fi
