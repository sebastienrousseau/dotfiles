#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.467) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT
# Script: clear.aliases.sh
# Version: 0.2.467
# Website: https://dotfiles.io

# 🅲🅻🅴🅰🆁 🅰🅻🅸🅰🆂🅴🆂

# Alias to change to the workspace directory
alias cdw="cd ~/workspace"

# Alias to clear the terminal screen
alias c="clear"

# Alias to clear the terminal screen and list the contents of the
# current directory
alias clc="clear && ls -a"

# Alias to clear the terminal screen and print the current working
# directory and the contents of the current directory
alias cpl="clear && pwd && echo '' && ls -a && echo ''"

# Alias to clear the terminal screen and print the current working
# directory and the directory tree
alias cplt="clear && pwd && echo '' && tree ./ && echo ''"

# Alias to clear the terminal screen and print the command history
alias clh="clear && history"

# Alias to clear the terminal screen
alias cl="c"

# Alias to clear the terminal screen and print the current
# working directory
alias clp="pwd"

# Alias to clear the terminal screen and print the directory tree
alias clt="clear && tree"
