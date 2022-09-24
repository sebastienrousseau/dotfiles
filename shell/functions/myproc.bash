#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# myproc: Function to list processes owned by an user
myproc() { ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command; }
