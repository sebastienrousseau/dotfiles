#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#                                                                           
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#  																			
# Custom Functions
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

# Load custom executable functions
for function in ~/zsh/functions/*; do
  source $function
done

# To be tested and triaged (multi-display support)
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
# 
# # aliasc: Function alias
# function aliasc() {
#   alias | grep "^${1}=" | awk -F= '{ print $2 }' | sed "s/^'//" | sed "s/'$//"
# }
