#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - PNPM Path configuration.

## 🅿🅽🅿🅼 🅿🅰🆃🅷🆂
if [ -z "$PNPM_HOME" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PNPM_HOME="$HOME"/Library/pnpm
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PNPM_HOME="$HOME"/.local/share/pnpm
  fi
  export PNPM_HOME
  export PATH="$PNPM_HOME:$PATH"
fi
