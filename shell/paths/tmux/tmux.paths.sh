#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.454) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆃🅼🆄🆇 🅿🅰🆃🅷🆂
if command -v 'tmux' >/dev/null; then
  TMUX_PATH=$(command -v tmux)
  export TMUX_PATH
fi

if [[ -z "${TMUX}" ]] && [[ ${UID} != 0 ]]; then
  tmux kill-session -t "Dotfiles (v0.2.454)" 2>/dev/null
  tmux new-session -t "Dotfiles (v0.2.454)"
fi
