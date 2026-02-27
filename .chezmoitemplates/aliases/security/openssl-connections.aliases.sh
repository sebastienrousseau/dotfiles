# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# OpenSSL Connection Testing
[[ -n "${_OPENSSL_CONNECTIONS_LOADED:-}" ]] && return 0
_OPENSSL_CONNECTIONS_LOADED=1

sslconnect() {
  [[ -z "$1" ]] && {
    echo "Usage: sslconnect <host> [port]"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}"
}

sslconnectsni() {
  [[ -z "$1" ]] && {
    echo "Usage: sslconnectsni <host> [port]"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -servername "$1"
}

sslciphers() {
  [[ -z "$1" || -z "$3" ]] && {
    echo "Usage: sslciphers <host> <port> <cipher_list>"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -cipher "$3"
}

sslshowcerts() {
  [[ -z "$1" ]] && {
    echo "Usage: sslshowcerts <host> [port]"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -showcerts
}

sslprotocol() {
  [[ -z "$1" || -z "$3" ]] && {
    echo "Usage: sslprotocol <host> <port> <protocol>"
    echo "Example: sslprotocol example.com 443 tls1_2"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -"$3"
}
