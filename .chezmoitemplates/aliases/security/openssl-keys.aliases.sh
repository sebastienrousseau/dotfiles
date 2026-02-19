# shellcheck shell=bash
# OpenSSL Key Operations
[[ -n "${_OPENSSL_KEYS_LOADED:-}" ]] && return 0
_OPENSSL_KEYS_LOADED=1

function sslgenrsa() {
  [[ -z "$1" ]] && {
    echo "Usage: sslgenrsa <key_file> [size]"
    echo "Default size: 2048"
    return 1
  }
  openssl genrsa -out "$1" "${2:-2048}"
}

function sslgenpkey() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: sslgenpkey <algorithm> <key_out>"
    echo "Example: sslgenpkey RSA mykey.pem"
    return 1
  }
  openssl genpkey -algorithm "$1" -out "$2"
}

function sslecparam() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: sslecparam <curve_name> <out_key>"
    echo "Example: sslecparam prime256v1 eckey.pem"
    return 1
  }
  openssl ecparam -name "$1" -genkey -out "$2"
}

function sslrsa() {
  [[ -z "$1" ]] && {
    echo "Usage: sslrsa <rsa_private_key_file>"
    return 1
  }
  openssl rsa -in "$1" -check
}

function sslrsainfo() {
  [[ -z "$1" ]] && {
    echo "Usage: sslrsainfo <rsa_private_key_file>"
    return 1
  }
  openssl rsa -in "$1" -text -noout
}

function sslrsapub() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: sslrsapub <rsa_private_key_file> <pub_key_out>"
    return 1
  }
  openssl rsa -in "$1" -pubout -out "$2"
}

function sslpkey() {
  [[ -z "$1" ]] && {
    echo "Usage: sslpkey <key_file> [additional_params]"
    return 1
  }
  openssl pkey -in "$1" "${@:2}"
}
