#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.454) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# whoisport: Function to find what is currently using a port.
whoisport() {
  port=$1
  pidInfo=$(fuser "${port}"/tcp 2>/dev/null)
  pid=$(echo "${pidInfo}" | cut -d':' -f2)
  ls -l /proc/"${pid}"/exe
}
