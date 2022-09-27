#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Function to combine cd and ls.

# cdls: Function to combine cd and ls.
cdls() {
  # Add \ because cd loops with alias
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] The operation completed successfully, directory listing of $1:"
  \cd "$1" || exit
  ls -lh
}

alias cdl='cdls' # alias for cdls