#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451)

# Load configuration files
# shellcheck disable=SC2154
# shellcheck disable=SC2002
# shellcheck disable=SC3000
# shellcheck disable=SC4000
# shellcheck disable=SC1091

# shellcheck source=/dev/null
. ./installer/"${lang}"/colors.sh

# shellcheck source=/dev/null
. ./installer/"${lang}"/04-utilities.sh

# Create the setup function
setup() {
	if [ -f ./tools/en/dotfiles-installer-en.sh ]; then
		./tools/en/dotfiles-installer-en.sh
	else
		error "$LINENO: Installer file \"${0}\" not found. Check the file name and try again. "
	fi
}

# Call the setup function
setup
