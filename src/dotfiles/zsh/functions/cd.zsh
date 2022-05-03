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

# cd: Function to Enable 'cd' into directory aliases
function cd() {
	if [ ${#1} == 0 ]; then
		builtin cd
	elif [ -d "${1}" ]; then
		builtin cd "${1}"
	elif [[ -f "${1}" || -L "${1}" ]]; then
		path=$(getTrueName "$1")
		builtin cd "$path"
	else
		builtin cd "${1}"
	fi
}
