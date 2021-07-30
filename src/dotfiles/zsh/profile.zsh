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
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


# Set JAVA_HOME
# For zsh shell, export $JAVA_HOME at ~/.zshenv or ~/.zshrc.
JAVA_HOME="$(brew --prefix)/Cellar/openjdk/15.0.2/libexec"
export JAVA_HOME
