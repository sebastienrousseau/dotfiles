# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Yazi wrapper for Zsh/Bash to cd on exit

yy() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
