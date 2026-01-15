#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# Setup VS Code command based on OS
if [[ "$(uname || true)" = "Darwin" ]]; then
  # macOS: create an alias to the VS Code CLI
  alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code" 2>/dev/null || true
elif [[ "$(uname || true)" = "Linux" ]]; then
  # Linux: code should be in PATH already
  true
fi

# Create convenient aliases for VS Code
alias vs="code" 2>/dev/null || true
alias vscode="code" 2>/dev/null || true

# vsc: Function to open a file in Visual Studio Code
# Only define if code command is available
if command -v code &>/dev/null; then
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
fi
