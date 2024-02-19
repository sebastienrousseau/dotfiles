#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

# 🆄🆄🅸🅳 🅰🅻🅸🅰🆂🅴🆂

# uuid: Generate a UUID and copy it to the clipboard.
if [[ "${OSTYPE}" == "darwin"* ]]; then
  if command -v 'uuidgen' >/dev/null; then
    # macOS
    alias uuid="uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]' | pbcopy && pbpaste && echo"
  fi
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  # Linux
  alias uuid="uuid | tr '[:upper:]' '[:lower:]' | xsel -ib && xsel -ob && echo"
fi
