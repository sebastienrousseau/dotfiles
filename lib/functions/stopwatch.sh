#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# stopwatch: Function for a stopwatch
stopwatch() {
  date1=$(gdate +%s)
  while true; do
    echo -ne "$(gdate -u --date @$(($(date +%s) - date1)) +%H:%M:%S)\r"
    sleep 0.1
  done
}
