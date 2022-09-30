#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# genpwd: Function to generates a strong random password of 20 characters (similar to Apple)
genpwd() {
    m=$(openssl rand -base64 32 | cut -c 1-6);
    a=$(openssl rand -base64 32 | cut -c 1-6);
    c=$(openssl rand -base64 32 | cut -c 1-6);
    pwd="$m-$a-$c";
    echo "[INFO] The password has been copied to the clipboard: $pwd"
    echo "$pwd"| pbcopy | pbpaste;
}
