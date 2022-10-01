#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

#   ----------------------------------------------------------------------------
#  	1.0 Setting PATH environments.
#   ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Prepend $PATH without duplicates.
##  ----------------------------------------------------------------------------

# prependpath: Prepend $PATH without duplicates
prependpath() {
    if ! echo "${PATH}" | tr ":" "\n" | grep -qx "$1" ; then
        PATH="$1:${PATH}"
    fi
}
