#!/usr/bin/env bash
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
