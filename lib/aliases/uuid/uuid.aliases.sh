#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🆄🆄🅸🅳 🅰🅻🅸🅰🆂🅴🆂
if command -v 'uuidgen' >/dev/null; then
  alias uuid="uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]'  | pbcopy && pbpaste && echo" # uuid: Generate a UUID and copy it to the clipboard.
fi
