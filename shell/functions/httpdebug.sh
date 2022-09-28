#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451)
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


# httpdebug: Function to download a web page and show info on what took time
httpdebug() { /usr/bin/curl "$@" -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\\n"; }
