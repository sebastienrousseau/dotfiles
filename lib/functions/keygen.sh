#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

# keygen: Function to generates SSH key
keygen() {
	if [[ $# -eq 0 ]]; then
		echo "What's the name of the Key (no space please)? "
		read -r name
		echo "What's the email associated with it? "
		read -r email
	elif [[ $# -eq 1 ]]; then
		name="$1"
		echo "What's the email associated with the key? "
		read -r email
	elif [[ $# -eq 2 ]]; then
		name="$1"
		email="$2"
	else
		echo "Usage: keygen [name] [email]"
		return 1
	fi

	ssh-keygen -t rsa -f ~/.ssh/id_rsa_"${name}" -C "${email}"
	ssh-add ~/.ssh/id_rsa_"${name}"
	pbcopy <~/.ssh/id_rsa_"${name}".pub
	echo "[INFO] SSH Key id_rsa_${name}.pub copied in your clipboard"
}
