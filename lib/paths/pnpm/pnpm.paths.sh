#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.458) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅿🅽🅿🅼 🅿🅰🆃🅷🆂
if [[ "${OSTYPE}" == "darwin"* ]]; then
  PNPM_HOME=/opt/homebrew/Cellar/pnpm
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  PNPM_HOME="${HOME}"/.local/share/pnpm
fi
export PNPM_HOME="${PNPM_HOME}"
export PATH="${PNPM_HOME}:${PATH}"
