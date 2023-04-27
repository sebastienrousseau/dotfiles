#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# Erases purgeable disk space with 0s on the selected disk
freespace() {
  if [[ -z "$1" ]]; then
    echo "Usage: $0 <disk>"
    echo "Example: $0 /dev/disk1s1"
    echo
    echo "Possible disks:"
    df -h | awk 'NR == 1 || /^\/dev\/disk/' || true
    return 1
  fi

  echo "Cleaning purgeable files from disk: $1 ...."
  diskutil secureErase freespace 0 "$1"
}
