#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Desription: Installation procedures for DotFiles v0.2.449.
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

# Load configuration files
# shellcheck disable=SC2154
# shellcheck disable=SC2002
# shellcheck disable=SC3000
# shellcheck disable=SC4000
# shellcheck disable=SC1091

# shellcheck source=/dev/null
. ./tools/"${lang}"/02-colors-en.sh

# shellcheck source=/dev/null
. ./tools/"${lang}"/04-utilities-en.sh

# Create the setup function
setup() {
  if [ -f ./07-docs-en.sh ]; then
    ./07-docs-en.sh
  else
    error "$LINENO: File \"${0}\" not found. Check the file name and try again. "
  fi
}

# Call the setup function
setup
