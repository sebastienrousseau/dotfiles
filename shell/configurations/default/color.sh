#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.455) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅲🅾🅻🅾🆁🆂
export colorflag='-G' # Enable color output

# Enable colored output from ls, etc. on FreeBSD-based systems
unset LSCOLORS LS_COLORS
export CLICOLOR=1
export CLICOLOR_FORCE=1

# LSCOLORS
if [[ "${OSTYPE}" == "darwin"* ]]; then
    export LSCOLORS="GxFxCxDxbxegedabagaced"
else
    export LS_COLORS="di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=34;43"
fi

# Tell grep to highlight matches
export GREP_OPTIONS='--color=auto'
