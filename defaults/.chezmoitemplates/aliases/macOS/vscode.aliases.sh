# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# VS Code Aliases

if command -v code &>/dev/null || [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
  fi

  # alias vsc="code" -> Managed by function in functions.sh
fi
