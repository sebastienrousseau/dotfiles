# shellcheck shell=bash
# OpenSSL Conversion Operations
[[ -n "${_OPENSSL_CONVERSION_LOADED:-}" ]] && return 0
_OPENSSL_CONVERSION_LOADED=1

function sslpkcs12() {
  [[ -z "$1" || -z "$2" || -z "$3" ]] && {
    echo "Usage: sslpkcs12 <cert_in> <key_in> <p12_out>"
    return 1
  }
  openssl pkcs12 -export -in "$1" -inkey "$2" -out "$3"
}

function sslpkcs12extract() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: sslpkcs12extract <p12_file> <out_file>"
    return 1
  }
  openssl pkcs12 -in "$1" -nodes -out "$2"
}

function sslpkcs8() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: sslpkcs8 <key_in> <key_out>"
    return 1
  }
  openssl pkcs8 -in "$1" -topk8 -out "$2"
}
