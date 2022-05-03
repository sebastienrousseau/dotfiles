#!/bin/sh
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
# Description: Add these lines to your .zshrc for aliases and functions
# Sections:
#
#   1.0 Sourcing alias plugins.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license


##  ----------------------------------------------------------------------------
##  1.0 Sourcing alias plugins.
##  ----------------------------------------------------------------------------

    # main aliases.
    source $ZSH_HOME/aliases/aliases.plugin.zsh

    # gcloud aliases.
    source $ZSH_HOME/aliases/gcloud/gcloud.plugin.zsh

    # git aliases.
    # TODO #18 Fix "fatal: not a git repository (or any of the parent directories): .git"
    source $ZSH_HOME/aliases/git/git.plugin.zsh

    # heroku aliases.
    source $ZSH_HOME/aliases/heroku/heroku.plugin.zsh

    # homebrew aliases.
    source $ZSH_HOME/aliases/homebrew/homebrew.plugin.zsh

    # jekyll aliases.
    source $ZSH_HOME/aliases/jekyll/jekyll.plugin.zsh

    # subversions aliases.
    source $ZSH_HOME/aliases/subversion/subversion.plugin.zsh
