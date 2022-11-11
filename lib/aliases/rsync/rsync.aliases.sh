#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🆁🆂🆈🅽🅲 🅰🅻🅸🅰🆂🅴🆂
if command -v 'rsync' >/dev/null; then
  alias rs='rsync -avz' # rs: Rsync with verbose and progress.
  alias rsync='rs'      # rsync: Rsync with verbose and progress.
fi
