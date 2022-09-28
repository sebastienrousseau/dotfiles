#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451) - Color configuration.

## 🅲🅾🅻🅾🆁🆂
export colorflag='-G' # Enable color output

# Enable colored output from ls, etc. on FreeBSD-based systems
unset LSCOLORS
export CLICOLOR=1
export CLICOLOR_FORCE=1

export LSCOLORS='GxFxCxDxBxegedabagaced'
# export LSCOLORS='Exfxcxdxbxegedabagacad'

# Tell grep to highlight matches
export GREP_OPTIONS='--color=auto'
