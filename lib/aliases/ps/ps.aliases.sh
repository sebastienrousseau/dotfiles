#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.464) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅿🆂 🅰🅻🅸🅰🆂🅴🆂 - PS aliases
if command -v 'ps' >/dev/null; then
  alias pid='ps -f'  # pid: Display the uid, pid, parent pid, recent CPU usage, process start time, controlling tty, elapsed CPU usage, and the associated command.
  alias ps='ps -ef'  # ps: Display all processes.
  alias psa='ps aux' # psa: List all processes.
fi
