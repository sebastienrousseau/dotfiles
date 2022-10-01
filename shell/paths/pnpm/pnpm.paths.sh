#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅿🅽🅿🅼 🅿🅰🆃🅷🆂
if [[ -z "${PNPM_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PNPM_HOME="${HOME}"/Library/pnpm
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    PNPM_HOME="${HOME}"/.local/share/pnpm
  fi
  export PNPM_HOME="${PNPM_HOME}"
  export PATH="${PNPM_HOME}:${PATH}"
fi
