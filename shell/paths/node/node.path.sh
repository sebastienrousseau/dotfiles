#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - PNPM Path configuration.

## 🅽🅾🅳🅴 🅿🅰🆃🅷
if [ -z "$NODE_PATH" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    NODE_PATH=$(which node)
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    NODE_PATH="$HOME"/.local/share/pnpm
  fi
  export NODE_PATH
  export PATH="$NODE_PATH:$PATH"
fi
