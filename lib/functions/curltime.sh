#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# Licensed under the MIT license
#

# Curl Time: Function to return the time it took to get a response from a given URL.
## get the timings for a curl to a URL
## usage: curltime $url
curltime() {
    curl -w "\n\
┌──────────────────────────────┐\n\
│Time appconnect:    %{time_appconnect}s │\n\
│Time connect:       %{time_connect}s │\n\
│Time namelookup:    %{time_namelookup}s │\n\
│Time pretransfer:   %{time_pretransfer}s │\n\
│Time redirect:      %{time_redirect}s │\n\
│Time starttransfer: %{time_starttransfer}s │\n\
└──────────────────────────────┘\n\
Time total:  %{time_total}s\n\n" -o /dev/null -s "$1"
}
alias clh='curlheader'   # Alias for curlheader
alias crlhd='curlheader' # Alias for curlheader
