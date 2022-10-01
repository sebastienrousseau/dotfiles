#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆃🅼🆄🆇 🅿🅰🆃🅷🆂
if command -v 'tmux' >/dev/null; then
  TMUX_PATH=$(command -v tmux)
  export TMUX_PATH

fi

if [[ -z "${TMUX}" ]] && [[ ${UID} != 0 ]]; then
  tmux attach -t default || tmux new -s default
fi
