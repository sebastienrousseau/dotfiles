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


# hostinfo: Function to display useful host related informaton
function hostinfo() {
	echo -e "\\nYou are logged on ${RED}$HOST"
	echo -e "\\nAdditionnal information:$NC "
	uname -a
	echo -e "\\n${RED}Users logged on:$NC "
	w -h
	echo -e "\\n${RED}Current date :$NC "
	date
	echo -e "\\n${RED}Machine stats :$NC "
	uptime
	echo -e "\\n${RED}Current network location :$NC "
	scselect
	echo -e "\\n${RED}Public facing IP Address :$NC "
	myip
	echo -e "\\n${RED}DNS Configuration:$NC "
	scutil --dns
	echo
}
