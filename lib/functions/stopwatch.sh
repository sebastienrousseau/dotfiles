#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# stopwatch: Function for a stopwatch
stopwatch() {
  date1=$(gdate +%s)
  while true; do
    echo -ne "$(gdate -u --date @$(($(date +%s) - date1)) +%H:%M:%S || true)\r"
    sleep 0.1
  done
}
