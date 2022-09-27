#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🅿🅻🆄🅶🅸🅽🆂

encode64() {
    if [[ $# -eq 0 ]]; then
        cat | base64
    else
        printf '%s' "$1" | base64 | base64
    fi
}

decode64() {
    if [[ $# -eq 0 ]]; then
        cat | base64 --decode
    else
        printf '%s\n' "$1" | base64 | base64 --decode
    fi
}

alias e64=encode64 # Encode to base64.
alias d64=decode64 # Decode from base64.
