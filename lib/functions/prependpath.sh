#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

#   ----------------------------------------------------------------------------
#  	1.0 Setting PATH environments.
#   ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Prepend $PATH without duplicates.
##  ----------------------------------------------------------------------------

# prependpath: Prepend $PATH without duplicates
prependpath() {
    if ! echo "${PATH}" | tr ":" "\n" | grep -qx "$1"; then
        PATH="$1:${PATH}"
    fi
}
