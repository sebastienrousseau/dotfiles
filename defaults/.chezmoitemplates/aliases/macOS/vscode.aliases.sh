# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# VS Code Aliases

if command -v code &>/dev/null || [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  if [[ "$(uname || true)" = "Darwin" ]]; then
    alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
  fi

  # alias vsc="code" -> Managed by function in functions.sh
fi
