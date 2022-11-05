#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🆆🅶🅴🆃 🅰🅻🅸🅰🆂🅴🆂
if command -v wget &>/dev/null; then
  alias wget='wget -c' # wget: Continue a partially-downloaded file.
  alias wg='wget'      # wg: wget.
fi
