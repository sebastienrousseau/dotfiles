#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - PNPM Path configuration.

## 🆃🅼🆄🆇 🅿🅰🆃🅷🆂
if command -v 'tmux'>/dev/null; then
  TMUX_PATH=$(command -v tmux)
  export TMUX_PATH

fi

if [[ -z "${TMUX}" ]] && [[ ${UID} != 0 ]]
then
    tmux attach -t default || tmux new -s default
fi
