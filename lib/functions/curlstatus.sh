#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.467) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## curlstatus: Function to return only the HTTP status code for a given URL.
## usage: curlstatus $url
curlstatus() {
  # shellcheck disable=SC1083
  echo "curl -k -s -o /dev/null -w \"%{http_code}\" \$1:"
  curl -k -s -o /dev/null -w "%{http_code}" "$1"
}
alias cs='curlstatus'       # Alias for curlstatus
alias cst='curlstatus'      # Alias for curlstatus
alias httpcode='curlstatus' # Alias for curlstatus
