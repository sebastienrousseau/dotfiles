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


# environment: Function to detect the current environment
function environment ()
{
    # Define a fallback `OS`
    LOCAL_OS="other"

    # Mac
    if [ "$(uname -s | grep -c Darwin)" -gt 0 ]; then
        LOCAL_OS="darwin"

    # Linux
    elif [ "$(uname -s | grep -c Linux)" -gt 0 ]; then
        LOCAL_OS="linux"

    # Windows via MING
    elif [ "$(uname -s | grep -c MING)" -gt 0 ]; then
        LOCAL_OS="win"

    # Cygwin
    elif [ "$(uname -s | grep -c Cygwin)" -gt 0 ]; then
        LOCAL_OS="win"

    # Cygwin via Babun
    elif [ "$(uname -s | grep -c CYGWIN)" -gt 0 ]; then
        LOCAL_OS="win"

    fi

    # Output the result
    echo "$LOCAL_OS"
    
}