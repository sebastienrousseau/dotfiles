# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
# OpenSSL Certificate Verification
[[ -n "${_OPENSSL_VERIFICATION_LOADED:-}" ]] && return 0
_OPENSSL_VERIFICATION_LOADED=1

sslverify() {
  [[ -z "$1" ]] && {
    echo "Usage: sslverify <certificate_file> [more_files]"
    return 1
  }
  openssl verify "$@"
}

sslverifycapath() {
  [[ -z "$1" ]] && {
    echo "Usage: sslverifycapath <certificate_file> [more_files]"
    return 1
  }
  openssl verify -CApath /etc/ssl/certs/ "$@"
}

sslcrl() {
  [[ -z "$1" ]] && {
    echo "Usage: sslcrl <crl_file>"
    return 1
  }
  openssl crl -in "$1" -text -noout
}
