#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# extract: Function to extract most know archives with one command
extract() {
	if [[ "$#" != 1 ]]; then
		echo "[ERROR] Please add one argument" >&2
		return 1
	fi

	if [[ -f "$1" ]]; then
		echo "[INFO] Extracting $1"
		case $1 in
		*.tar.bz2) tar xjf "$1" ;;
		*.tar.gz) tar xzf "$1" ;;
		*.bz2) bunzip2 "$1" ;;
		*.rar) unrar e "$1" ;;
		*.gz) gunzip "$1" ;;
		*.tar) tar xf "$1" ;;
		*.tbz2) tar xjf "$1" ;;
		*.tgz) tar xzf "$1" ;;
		*.zip) unzip "$1" ;;
		*.Z) uncompress "$1" ;;
		*.7z) 7z x "$1" ;;
		*) echo "[ERROR] '$1' cannot be extracted via extract()" ;;
		esac
	else
		echo "[ERROR] '$1' is not a valid file"
	fi
}
