#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# myproc: Function to list processes owned by an user
myproc() { ps "$@" -u "${USER}" -o pid,%cpu,%mem,start,time,command; }
