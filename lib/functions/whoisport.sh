#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# whoisport: Function to find what is currently using a port.
whoisport() {
  port=$1
  pidInfo=$(fuser "${port}"/tcp 2>/dev/null)
  pid=$(echo "${pidInfo}" | cut -d':' -f2)
  ls -l /proc/"${pid}"/exe
}
