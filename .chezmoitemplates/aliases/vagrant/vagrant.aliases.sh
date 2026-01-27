# shellcheck shell=bash
# Vagrant aliases

if command -v vagrant &>/dev/null; then
  if ! alias v >/dev/null 2>&1; then
    alias v='vagrant'
  fi
fi
