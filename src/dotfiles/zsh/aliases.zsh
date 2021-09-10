#!/bin/sh
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
# Description: Add these lines to your .zshrc for aliases and functions
# Sections:
#
#   1.0 Sourcing alias plugins.
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license


##  ----------------------------------------------------------------------------
##  1.0 Sourcing alias plugins.
##  ----------------------------------------------------------------------------

if [[ -f $ZSH_HOME/aliases/gcloud/gcloud.plugin.zsh ]]; then
    # gcloud aliases.
    source $ZSH_HOME/aliases/gcloud/gcloud.plugin.zsh
fi

if [[ -f $ZSH_HOME/aliases/git/git.plugin.zsh ]]; then
    # git aliases.
    source $ZSH_HOME/aliases/git/git.plugin.zsh
fi

if [[ -f $ZSH_HOME/aliases/heroku/heroku.plugin.zsh ]]; then
    # heroku aliases.
    source $ZSH_HOME/aliases/heroku/heroku.plugin.zsh
fi

if [[ -f $ZSH_HOME/aliases/homebrew/homebrew.plugin.zsh ]]; then
    # homebrew aliases.
    source $ZSH_HOME/aliases/homebrew/homebrew.plugin.zsh
fi

if [[ -f $ZSH_HOME/aliases/jekyll/jekyll.plugin.zsh ]]; then
    # jekyll aliases.
    source $ZSH_HOME/aliases/jekyll/jekyll.plugin.zsh
fi

if [[ -f $ZSH_HOME/aliases/subversion/subversion.plugin.zsh ]]; then
    # subversions aliases.
    source $ZSH_HOME/aliases/subversion/subversion.plugin.zsh
fi