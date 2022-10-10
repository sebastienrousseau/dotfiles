#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.457) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# vsc: Function to open a file in Visual Studio Code.

vsc() {
  if [[ -z "$1" ]]; then
    echo "Usage: vsc <file>"
    return 1
  fi

  if [[ -f "$1" ]]; then
    code "$1"
  else
    echo "File not found: $1"
    return 1
  fi
}

if [[ "$(uname || true)" = "Darwin" ]]; then
  alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
elif [[ "$(uname || true)" = "Linux" ]]; then
  alias code="code"
fi

alias vs="code"
alias vsc="code"
alias vscode="code"

