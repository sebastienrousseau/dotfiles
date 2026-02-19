# shellcheck shell=bash
# OpenSSL Certificate Operations
[[ -n "${_OPENSSL_CERTS_LOADED:-}" ]] && return 0
_OPENSSL_CERTS_LOADED=1

alias sslx509='openssl x509' # X.509 certificate utility

function sslx509info() {
  [[ -z "$1" ]] && {
    echo "Usage: sslx509info <certificate_file>"
    return 1
  }
  openssl x509 -in "$1" -text -noout
}

function sslx509fp() {
  [[ -z "$1" ]] && {
    echo "Usage: sslx509fp <certificate_file>"
    return 1
  }
  openssl x509 -in "$1" -fingerprint -noout
}

function sslx509dates() {
  [[ -z "$1" ]] && {
    echo "Usage: sslx509dates <certificate_file>"
    return 1
  }
  openssl x509 -in "$1" -dates -noout
}

function sslx509subject() {
  [[ -z "$1" ]] && {
    echo "Usage: sslx509subject <certificate_file>"
    return 1
  }
  openssl x509 -in "$1" -subject -noout
}

function sslx509issuer() {
  [[ -z "$1" ]] && {
    echo "Usage: sslx509issuer <certificate_file>"
    return 1
  }
  openssl x509 -in "$1" -issuer -noout
}

function sslx509check() {
  [[ -z "$1" ]] && {
    echo "Usage: sslx509check <certificate_file>"
    return 1
  }
  openssl x509 -purpose -in "$1" -noout
}

function sslx509extract() {
  [[ -z "$1" || -z "$2" || -z "$3" ]] && {
    echo "Usage: sslx509extract <in_cert> <out_format> <out_file>"
    echo "Example: sslx509extract cert.pem DER cert.der"
    return 1
  }
  openssl x509 -in "$1" -outform "$2" -out "$3"
}
