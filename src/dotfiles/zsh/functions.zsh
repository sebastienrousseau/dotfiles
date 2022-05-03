#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.448
# https://dotfiles.io
#                                                                           
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#  																			
# Custom Functions
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#

# Load custom executable functions
for function in $ZSH_HOME/functions/[^.#]*.zsh; do
  source $function
done

# TODO: #19 To be tested and triaged (multi-display support)
#
# set dual monitors
# dual () {
#     xrandr --output eDP1 --primary --left-of HDMI1 --output HDMI1 --mode 1280x720
# }
# 
# dual2 () {
#     xrandr --output eDP1 --primary --left-of HDMI1 --output HDMI1 --auto
# }
# 
# # set single monitor
# single () {
#     xrandr --output HDMI1 --off
# }
# 
# 
# TODO: #20 Test Function alias
# # aliasc: Function alias
# function aliasc() {
#   alias | grep "^${1}=" | awk -F= '{ print $2 }' | sed "s/^'//" | sed "s/'$//"
# }
