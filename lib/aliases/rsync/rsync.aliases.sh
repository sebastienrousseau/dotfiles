#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🆁🆂🆈🅽🅲 🅰🅻🅸🅰🆂🅴🆂

if command -v 'rsync' >/dev/null; then

  # Rsync with verbose and progress.
  alias rs='rsync -avz'

  # Rsync with verbose and progress.
  alias rsync='rs'
fi
