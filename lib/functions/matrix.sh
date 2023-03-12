#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# matrix: Function to Enable Matrix Effect in the terminal
matrix() {
	# Set the color of the output
	tput setaf 2 # green

	while :; do
		# Generate random numbers
		read -r LINES COLUMNS x y <<<"$(
			tput lines || true
			tput cols || true
			shuf -i 1-100 -n 2 || true
		)"

		# Update the matrix animation
		for ((i = 0; i < LINES; i++)); do
			# Move the cursor to the appropriate position
			tput cup $i $y

			# Print the character in green
			tput setaf 2 # green
			printf "%s" "${RANDOM:0:1}"

			# Move the cursor to the next position
			tput cup $((i - 1)) $y

			# Print the character in white
			tput setaf 7 # white
			printf "%s" "${RANDOM:0:1}"
		done

		# Sleep for a short duration
		sleep 0.05
	done
}
