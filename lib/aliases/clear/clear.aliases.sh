#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets aliases for the `clear` command.
# License: MIT
# Script: clear.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅲🅻🅴🅰🆁 🅰🅻🅸🅰🆂🅴🆂
if command -v 'clear' >/dev/null; then
  alias c="clear"                                            # c: Clear the terminal screen.
  alias cl="c"                                               # cl: Clear the terminal screen.
  alias cla="clear && echo ''"                               # cla: Clear the terminal screen and print an empty line.
  alias clc="clear && cat"                                   # clc: Clear the terminal screen and print the contents of the current directory.
  alias clcat="clc"                                          # clcat: Clear the terminal screen and print the contents of the current directory.
  alias cld="clear && cd"                                    # cld: Clear the terminal screen and change to the specified directory.
  alias cldi="clear && cd .."                                # cldi: Clear the terminal screen and move up one directory level.
  alias cle="clear && exit"                                  # cle: Clear the terminal screen and exit the terminal.
  alias clg="clear && git status"                            # clg: Clear the terminal screen and print the current Git status.
  alias clh="clear && history"                               # clh: Clear the terminal screen and print the command history.
  alias clhist="clh"                                         # clhist: Clear the terminal screen and print the command history.
  alias cli="clear && sudo -i"                               # cli: Clear the terminal screen and start a new shell as the root user.
  alias clj="clear && jobs"                                  # clj: Clear the terminal screen and print the current jobs.
  alias clk="clear && killall"                               # clk: Clear the terminal screen and kill all processes matching the specified name.
  alias clp="clear && pwd"                                   # clp: Clear the terminal screen and print the current working directory.
  alias clpwd="clp"                                          # clpwd: Clear the terminal screen and print the current working directory.
  alias clq="clear && exit"                                  # clq: Clear the terminal screen and exit the terminal.
  alias clr="c"                                              # clr: Clear the terminal screen.
  alias cls="c"                                              # cls: Clear the terminal screen.
  alias clt="clear && tree"                                  # clt: Clear the terminal screen and print the directory tree.
  alias cltree="clt"                                         # cltree: Clear the terminal screen and print the directory tree.
  alias clu="clear && cd .. && pwd"                          # clu: Clear the terminal screen, move up one directory level, and print the new working directory.
  alias clup="clear && cd ../.."                             # clup: Clear the terminal screen and move up two directory levels.
  alias clv="clear && virtualenvwrapper"                     # clv: Clear the terminal screen and print the current virtualenvwrapper information.
  alias ct="clear && tree ./"                                # ct: Clear the terminal screen and print the directory tree.
  alias ctree="ct"                                           # ctree: Clear the terminal screen and print the directory tree.
  alias cpl="clear && pwd && echo '' && ls -a && echo ''"    # cpl: Clear the terminal screen and print the current working directory and the contents of the current directory.
  alias cplt="clear && pwd && echo '' && tree ./ && echo ''" # cplt: Clear the terminal screen and print the current working directory and the directory tree.
fi
