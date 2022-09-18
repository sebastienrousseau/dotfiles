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
# Prompt configuration
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#

# Normal prompt (👽) & Root prompt (😈)
# PROMPT='%(!.😈 %F{red}%S%n%s%f %F{red}❱❱❱%f .👽 %F{green}%S%n%s%f %F{green}❱❱❱%f )'
PROMPT='%(?.%F{green}√.%F{red}?%?)%f %F{green}%1% ~ $%f '
export PROMPT

# RPROMPT='%(!.%F{red}%B%U%d%b%u%f.%F{green}%B%U%d%b%u%f)'
RPROMPT='%B%F{cyan}%*%f%b'
export RPROMPT

# Force prompt to write history after every command.
PROMPT_COMMAND='history -a; $PROMPT_COMMAND'
export PROMPT_COMMAND
