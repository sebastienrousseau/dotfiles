#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description: Constant variables for the Skeletonic Stylus Documentation (v0.0.1).
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

# Define variables
# shellcheck disable=SC2034  # Unused variables left for readability

appName=dotfiles
fileVersion=v0.2.450.zip
backupDirectory=dotfiles_backup
directory=dotfiles
progName="$(basename "$0")"

# The location of the logs directory
logsDirectory="$HOME/.$appName"

# The location of the Dotfiles log file
logFile="$logsDirectory/$appName-$(date +%F).log"

# Make a temporary directory instead of a file.
tempDir=$(mktemp -d)

tools=tools
version=$(git rev-parse --short head)
webUrl="https://github.com/sebastienrousseau/dotfiles/archive/refs/tags"
