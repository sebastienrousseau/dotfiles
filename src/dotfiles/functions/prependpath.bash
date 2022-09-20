#! /bin/bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Sections:
#
#   1.0 Setting PATH environments.
#      1.1 Prepend $PATH without duplicates.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


#   ----------------------------------------------------------------------------
#  	1.0 Setting PATH environments.
#   ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Prepend $PATH without duplicates.
##  ----------------------------------------------------------------------------

# prependpath: Prepend $PATH without duplicates
prependpath() {
    if ! echo "$PATH" | tr ":" "\n" | grep -qx "$1" ; then
        PATH="$1:$PATH"
    fi
}
