#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Function to return only a specific response header or all response headers for a given URL.
#

## curlheader: Function to return only a specific response header or all response headers for a given URL.
## usage: curlheader $header $url
## usage: curlheader $url
curlheader() {
  if [[ -z "$2" ]]; then
    echo "curl -k -s -D - $1 -o /dev/null"
    curl -k -s -D - "$1" -o /dev/null:
  else
    echo "curl -k -s -D - $2 -o /dev/null | grep $1:"
    curl -k -s -D - "$2" -o /dev/null | grep "$1":
  fi
}

alias clh='curlheader' # Alias for curlheader
alias crlhd='curlheader' # Alias for curlheader
