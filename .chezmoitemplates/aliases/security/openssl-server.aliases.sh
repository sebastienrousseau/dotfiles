# shellcheck shell=bash
# OpenSSL Server & CA Operations
[[ -n "${_OPENSSL_SERVER_LOADED:-}" ]] && return 0
_OPENSSL_SERVER_LOADED=1

# CA Operations
function sslca() {
  # Typically requires a CA config file. Adjust as needed.
  openssl ca "$@"
}

# Speed Testing
alias sslspeed='openssl speed'

# Server Testing and Setup
function sslserver() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: sslserver <cert_file> <key_file> [port]"
    echo "Default port: 4433"
    return 1
  fi
  openssl s_server -cert "$1" -key "$2" -port "${3:-4433}"
}
