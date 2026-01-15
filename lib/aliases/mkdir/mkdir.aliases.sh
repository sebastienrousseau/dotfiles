#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅼🅰🅺🅴🅳🅸🆁 🅰🅻🅸🅰🆂🅴🆂

# Make directory and cd into it.
alias mcd='mkdir -pv && cd'

# Make example directory with current date.
alias mde='mkdir -pv "$(date +%Y%m%d)-example"'

# Make directory.
alias md='mkdir -v'

# Make directory with date.
alias mdd='mkdir -pv $(date +%Y%m%d) && cd $(date +%Y%m%d)'

# Make notes directory with current date.
alias mdn='mkdir -pv "$(date +%Y%m%d)-notes"'

# Make work directory with current date.
alias mdw='mkdir -pv "$(date +%Y%m%d)-work"'

# Make directory with time.
alias mdt='mkdir -pv $(date +%H%M%S)'
