# shellcheck shell=bash
# OpenSSL Connection Testing
[[ -n "${_OPENSSL_CONNECTIONS_LOADED:-}" ]] && return 0
_OPENSSL_CONNECTIONS_LOADED=1

function sslconnect() {
  [[ -z "$1" ]] && {
    echo "Usage: sslconnect <host> [port]"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}"
}

function sslconnectsni() {
  [[ -z "$1" ]] && {
    echo "Usage: sslconnectsni <host> [port]"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -servername "$1"
}

function sslciphers() {
  [[ -z "$1" || -z "$3" ]] && {
    echo "Usage: sslciphers <host> <port> <cipher_list>"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -cipher "$3"
}

function sslshowcerts() {
  [[ -z "$1" ]] && {
    echo "Usage: sslshowcerts <host> [port]"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -showcerts
}

function sslprotocol() {
  [[ -z "$1" || -z "$3" ]] && {
    echo "Usage: sslprotocol <host> <port> <protocol>"
    echo "Example: sslprotocol example.com 443 tls1_2"
    return 1
  }
  openssl s_client -connect "$1:${2:-443}" -"$3"
}
