#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

## 🆃🅼🆄🆇 🅿🅰🆃🅷🆂
if command -v 'tmux' >/dev/null; then
  TMUX_PATH=$(command -v tmux)
  export TMUX_PATH
fi
