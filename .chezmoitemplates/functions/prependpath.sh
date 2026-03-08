# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#   ----------------------------------------------------------------------------
#  	1.0 Setting PATH environments.
#   ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Prepend $PATH without duplicates.
##  ----------------------------------------------------------------------------

# prependpath: Prepend $PATH without duplicates
prependpath() {
  if [[ ":${PATH}:" != *":$1:"* ]]; then
    PATH="$1:${PATH}"
  fi
}
