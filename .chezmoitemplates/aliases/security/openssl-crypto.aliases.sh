# shellcheck shell=bash
# OpenSSL Cryptographic Operations (Hash, Digest, Random, Encryption)
[[ -n "${_OPENSSL_CRYPTO_LOADED:-}" ]] && return 0
_OPENSSL_CRYPTO_LOADED=1

# Hash and Digest Functions
function ssldigest() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: ssldigest <algorithm> <file>"
    echo "Example: ssldigest sha256 file.txt"
    return 1
  }
  openssl dgst -"$1" "$2"
}

alias sslsha1='openssl dgst -sha1'
alias sslsha256='openssl dgst -sha256'
alias sslsha384='openssl dgst -sha384'
alias sslsha512='openssl dgst -sha512'
alias sslmd5='openssl dgst -md5' # Not recommended for security

# Random Generation
function sslrand() {
  [[ -z "$1" ]] && {
    echo "Usage: sslrand <size>"
    return 1
  }
  openssl rand -hex "$1"
}

function sslrandraw() {
  [[ -z "$1" ]] && {
    echo "Usage: sslrandraw <size>"
    return 1
  }
  openssl rand "$1"
}

function sslrandhex() {
  [[ -z "$1" ]] && {
    echo "Usage: sslrandhex <size>"
    return 1
  }
  openssl rand -hex "$1"
}

function sslrandbase64() {
  [[ -z "$1" ]] && {
    echo "Usage: sslrandbase64 <size>"
    return 1
  }
  openssl rand -base64 "$1"
}

# Encryption and Decryption
function sslenc() {
  if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
    echo "Usage: sslenc <cipher> <in_file> <out_file> [additional_params]"
    echo "Example: sslenc aes-256-cbc secret.txt secret.enc -pbkdf2 -iter 10000"
    return 1
  fi
  openssl enc -"$1" -e -in "$2" -out "$3" "${@:4}"
}

function ssldec() {
  if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
    echo "Usage: ssldec <cipher> <in_file> <out_file> [additional_params]"
    echo "Example: ssldec aes-256-cbc secret.enc secret.dec -pbkdf2 -iter 10000"
    return 1
  fi
  openssl enc -"$1" -d -in "$2" -out "$3" "${@:4}"
}

function sslaesenc() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: sslaesenc <in_file> <out_file>"
    return 1
  fi
  openssl enc -aes-256-cbc -salt -in "$1" -out "$2" -iter 10000 -pbkdf2
}

function sslaesdec() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: sslaesdec <in_file> <out_file>"
    return 1
  fi
  openssl enc -aes-256-cbc -d -in "$1" -out "$2" -iter 10000 -pbkdf2
}
