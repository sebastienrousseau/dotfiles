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
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license


# Enable colors in prompt
autoload -Uz colors && colors

# Enable command completion
# autoload -Uz compinit && compinit -u

# Don't enable any fancy or breaking features if the shell session is non-interactive
if [[ $- != *i* ]] ; then
  return
fi

# Current Version of DotFiles
export DOTFILES_VERSION='0.2.447'

# Current location of DotFiles
export DOTFILES_HOME=$HOME/.dotfiles

# Targeted directory of DotFiles
export DOTFILES_TARGET_DIR=$HOME


if [ -z "$DOTFILES_HOME" ]; then
  # TODO: #17 Add update routine
fi

if ! test -d "$DOTFILES_HOME"; then
  mkdir "$DOTFILES_HOME"
  chmod g-w "$DOTFILES_HOME"
  chmod o-w "$DOTFILES_HOME"
fi

# Fix array index for zsh
if [ "$ZSH_NAME" = "zsh" ];then
  setopt localoptions ksharrays
fi

# Set the path of zsh configuration directory
if [[ -z "$ZSH_HOME" ]]; then
  export ZSH_HOME="$HOME/.zsh"
fi

# Set the path of zsh aliases directory
if [[ -z "$ZSH_ALIASES" ]]; then
  export ZSH_ALIASES="$ZSH_HOME/dotfiles/zsh/plugins/aliases"
fi

# Source the aliases.zsh file.
if [[ -z "ZSH_ALIASES" ]] ; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$ZSH_ALIASES/aliases.plugin.zsh"
fi

# Source the configurations.zsh file.
if [[ -f ~/configurations.zsh ]]; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/configurations.zsh"
fi

# Source the profile.zsh file.
if [[ -f ~/profile.zsh ]] ; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/profile.zsh"
fi

# Source the functions.zsh file.
if [[ -f ~/functions.zsh ]]; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/functions.zsh"
fi

# Source the exit.zsh file.
if [[ -f ~/exit.zsh ]]; then
  # File may not exist, so don't follow for shellcheck linting (SC1090).
  # shellcheck source=/dev/null
  source "$HOME/exit.zsh"
fi
