# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Nmap Scanning Aliases
[[ -n "${_NMAP_SCANNING_LOADED:-}" ]] && return 0
_NMAP_SCANNING_LOADED=1
# Wrapped in if/fi, not `|| return 0`: this file is concatenated into
# 91-ux-aliases-lazy.sh, where a top-level return would stop every
# alias file after it from loading.
if command -v nmap >/dev/null 2>&1; then

  # NOTE:
  # Nmap aliases were consolidated into `system/system.aliases.sh`
  # so runtime diagnostics aliases live in a single module.

  nmscript() {
    [[ -z "$1" || -z "$2" ]] && {
      echo "Usage: nmscript <script_name> <target>"
      return 1
    }
    nmap --script "$1" "$2"
  }
fi
