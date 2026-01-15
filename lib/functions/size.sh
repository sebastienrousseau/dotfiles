#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 - size
# Made with ♥ by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# size: Function to check a file size
size() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument (file or directory)" >&2
    return 1
  fi

  stat -f '[INFO] Directory total size: %z bytes' "$1"
}
