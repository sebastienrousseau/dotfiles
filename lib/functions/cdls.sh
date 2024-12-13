#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# Function to combine cd and ls.
# cdls: Function to combine cd and ls.
cdls() {
  cd "$@" && ls
}

alias cdl='cdls' # alias for cdls
