#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
set -euo pipefail

if command -v lolcat >/dev/null; then
  if [[ $# -gt 0 ]]; then
    cat "$@" | lolcat
  else
    lolcat
  fi
  exit 0
fi

# Fallback: plain output
if [[ $# -gt 0 ]]; then
  cat "$@"
else
  cat
fi
