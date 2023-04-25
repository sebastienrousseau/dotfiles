#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# myproc: Function to list processes owned by an user
myproc() { ps "$@" -u "${USER}" -o pid,%cpu,%mem,start,time,bsdtime,command; }
