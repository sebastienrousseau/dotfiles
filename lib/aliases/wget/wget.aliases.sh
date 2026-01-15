#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🆆🅶🅴🆃 🅰🅻🅸🅰🆂🅴🆂
if command -v 'wget' >/dev/null; then

  # wget.
  alias wg='wget'

  # wget with continue.
  alias wgc='wg'

  # wget with robots=off.
  alias wge='wg -e robots=off'

  # wget with continue.
  alias wget='wget -c'
fi
