#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# Function to combine cd and ls.
# cdls: Function to combine cd and ls.
cdls() {
  cd "$@" && ls
}

alias cdl='cdls' # alias for cdls
