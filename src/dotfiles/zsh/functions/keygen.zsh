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
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# keygen: Function to generates SSH key
function keygen() {

	echo "What's the name of the Key (no space please) ? ";
	read -r name;

	echo "What's the email associated with it? ";
	read -r email;

	echo $(ssh-keygen -t rsa -f ~/.ssh/id_rsa_$name -C "$email");

	ssh-add ~/.ssh/id_rsa_$name;

	pbcopy < ~/.ssh/id_rsa_$name.pub;

	echo "[INFO] SSH Key id_rsa_$name.pub copied in your clipboard";

}
