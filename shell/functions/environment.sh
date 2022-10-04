#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.453) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# environment: Function to detect the current environment
environment ()
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
