#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🆆🅶🅴🆃 🅰🅻🅸🅰🆂🅴🆂
if command -v 'wget' >/dev/null; then
  alias wg='wget'              # wg: wget.
  alias wgc='wg'               # wgc: wget with continue.
  alias wge='wg -e robots=off' # wge: wget with robots=off.
  alias wget='wget -c'         # wget: wget with continue.
fi
