# shellcheck shell=bash
# OpenSSL CSR (Certificate Signing Request) Operations
[[ -n "${_OPENSSL_CSR_LOADED:-}" ]] && return 0
_OPENSSL_CSR_LOADED=1

alias sslreq='openssl req'

function sslreqnew() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: sslreqnew <key_out> <csr_out>"
    return 1
  }
  openssl req -new -nodes -keyout "$1" -out "$2"
}

function sslreqinfo() {
  [[ -z "$1" ]] && {
    echo "Usage: sslreqinfo <csr_file>"
    return 1
  }
  openssl req -in "$1" -text -noout
}

function sslreqverify() {
  [[ -z "$1" ]] && {
    echo "Usage: sslreqverify <csr_file>"
    return 1
  }
  openssl req -verify -in "$1"
}
