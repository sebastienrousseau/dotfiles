#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.460) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# hostinfo: Function to display useful host related informaton
hostinfo() {
	echo "You are logged on"
	$HOST
	echo "Additionnal information: "
	uname -a
	echo "Users logged on: "
	w -h
	echo "Current date : "
	date
	echo "Machine stats : "
	uptime
	echo "Current network location : "
	scselect
	echo "Public facing IP Address : "
	myip
	echo "DNS Configuration: "
	scutil --dns
	echo
}
