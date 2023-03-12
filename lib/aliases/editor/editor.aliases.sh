#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets Editor Aliases
# License: MIT
# Script: editor.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂
editors="nano vim vi code gedi notepad++"
for editor in ${editors}; do
  if command -v "${editor}" &>/dev/null; then
    case "${editor}" in
    "nano")
      alias n='nano'        # n: Edit a file with Nano.
      alias nano1='nano -c' # nano1: Edit a file with Nano, with cursor position display.
      alias nanos='nano -S' # nanos: Edit a file with Nano, soft wrapping enabled.
      ;;
    "vim" | "vi")
      alias v='vim'               # v: Edit a file with Vim.
      alias vi='vim'              # vi: Edit a file with Vim.
      alias vimdiff='vim -d'      # vimdiff: Compare two files with Vimdiff.
      alias vimh='vim -u NONE -N' # vimh: Edit a file with Vim in no compatible mode.
      alias vims='vim -S'         # vims: Edit a file with Vim, sourcing the given session file.
      ;;
    "code")
      alias c='code'                          # c: Edit a file with Visual Studio Code.
      alias code1='code --disable-extensions' # code1: Edit a file with Visual Studio Code, with extensions disabled.
      alias codef='code --new-window'         # codef: Open a new instance of Visual Studio Code.
      alias cdiff='code --diff'               # cdiff: Compare two files with Visual Studio Code.
      ;;
    "gedi")
      alias g='gedit'         # g: Edit a file with Gedit.
      alias gedit1='gedit -w' # gedit1: Edit a file with Gedit and wait until it is closed.
      alias geditd='gedit -s' # geditd: Edit a file with Gedit, with split view enabled.
      ;;
    "notepad++")
      alias npp='notepad++'             # npp: Edit a file with Notepad++.
      alias npp1='notepad++ -nosession' # npp1: Edit a file with Notepad++, without restoring a previous session.
      ;;
    *) ;;
    esac
    alias e='${editor}'      # e: Edit a file.
    alias edit='${editor}'   # edit: Edit a file.
    alias editor='${editor}' # editor: Edit a file.
    alias mate='${editor}'   # mate: Edit a file.
    alias n='${editor}'      # n: Edit a file.
    alias v='${editor}'      # v: Edit a file.
    break
  fi
done
