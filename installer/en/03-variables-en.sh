#!/usr/bin/env bash
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
export appName
fileVersion=v0.2.450.zip
export fileVersion
backupDirectory=dotfiles_backup
export backupDirectory
directory=dotfiles
export directory
progName="$(basename "$0")"
export progName

# The location of the logs directory
logsDirectory="$HOME/.$appName"

# The location of the Dotfiles log file
logFile="$logsDirectory/$appName-$(date +%F).log"

# Make a temporary directory instead of a file.
tempDir=$(mktemp -d)

#tools=tools
#version=$(git rev-parse --short head)
#webUrl="https://github.com/sebastienrousseau/dotfiles/archive/refs/tags"
