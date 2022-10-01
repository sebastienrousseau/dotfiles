#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅲🅾🅻🅾🆁🆂
export colorflag='-G' # Enable color output

# Enable colored output from ls, etc. on FreeBSD-based systems
unset LSCOLORS
export CLICOLOR=1
export CLICOLOR_FORCE=1

export LSCOLORS='GxFxCxDxBxegedabagaced'

# Tell grep to highlight matches
export GREP_OPTIONS='--color=auto'
