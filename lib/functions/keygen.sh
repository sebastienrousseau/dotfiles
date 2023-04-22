#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# keygen: Function to generates SSH key
keygen() {

	echo "What's the name of the Key (no space please) ? "
	read -r name

	echo "What's the email associated with it? "
	read -r email

	ssh-keygen -t rsa -f ~/.ssh/id_rsa_"${name}" -C "${email}"

	ssh-add ~/.ssh/id_rsa_"${name}"

	pbcopy <~/.ssh/id_rsa_"${name}".pub

	echo "[INFO] SSH Key id_rsa_$(name).pub copied in your clipboard"

}
