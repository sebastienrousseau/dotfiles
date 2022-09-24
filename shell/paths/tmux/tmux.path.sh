#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - PNPM Path configuration.

## 🆃🅼🆄🆇 🅿🅰🆃🅷🆂
if command -v 'tmux'>/dev/null; then
  TMUX_PATH=$(command -v tmux)
  export TMUX_PATH
fi

if [ "$TMUX" = "" ]; then tmux; fi
