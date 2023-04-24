#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂

editors="nano vim vi code gedi notepad++"
for editor in ${editors}; do
  if command -v "${editor}" &>/dev/null; then
    # Edit aliases
    alias e='${editor}'      # e: Edit a file.
    alias edit='${editor}'   # edit: Edit a file.
    alias editor='${editor}' # editor: Edit a file.
    alias mate='${editor}'   # mate: Edit a file.
    alias n='${editor}'      # n: Edit a file.
    alias v='${editor}'      # v: Edit a file.

    break
  fi
done
