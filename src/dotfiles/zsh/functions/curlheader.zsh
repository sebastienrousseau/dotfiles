#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.449
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


## curlheader will return only a specific response header or all response headers for a given URL
## usage: curlheader $header $url
## usage: curlheader $url
function curlheader() {
  if [[ -z "$2" ]]; then
    echo "curl -k -s -D - $1 -o /dev/null"
    curl -k -s -D - $1 -o /dev/null:
  else
    echo "curl -k -s -D - $2 -o /dev/null | grep $1:"
    curl -k -s -D - $2 -o /dev/null | grep $1:
  fi
}
