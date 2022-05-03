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


## get the timings for a curl to a URL
## usage: curltime $url
function curltime(){
  curl -w "   time_namelookup:  %{time_namelookup}\n\
      time_connect:  %{time_connect}\n\
   time_appconnect:  %{time_appconnect}\n\
  time_pretransfer:  %{time_pretransfer}\n\
     time_redirect:  %{time_redirect}\n\
time_starttransfer:  %{time_starttransfer}\n\
--------------------------\n\
        time_total:  %{time_total}\n" -o /dev/null -s "$1"
}
