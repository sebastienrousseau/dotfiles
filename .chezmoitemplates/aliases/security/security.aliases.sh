# shellcheck shell=bash
# Security Aliases - Main loader
# Loads all security tool submodules based on available commands

[[ -n "${_SECURITY_ALIASES_LOADED:-}" ]] && return 0
_SECURITY_ALIASES_LOADED=1

# `strict` enables high-impact aliases (firewall mutation, etc.).
_DOTFILES_SECURITY_MODE="${DOTFILES_SECURITY_MODE:-standard}"

# Get the directory containing this script
_SECURITY_ALIASES_DIR="${BASH_SOURCE[0]%/*}"

# OpenSSL aliases
if command -v openssl >/dev/null 2>&1; then
  # Basic Aliases
  alias ssl='openssl'          # OpenSSL shortcut
  alias sslv='openssl version' # Show OpenSSL version
  alias sslhelp='openssl help' # Show OpenSSL help

  # Load OpenSSL submodules
  for _module in \
    openssl-certs \
    openssl-csr \
    openssl-keys \
    openssl-conversion \
    openssl-connections \
    openssl-verification \
    openssl-crypto \
    openssl-server; do
    # shellcheck source=/dev/null
    [[ -f "${_SECURITY_ALIASES_DIR}/${_module}.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/${_module}.aliases.sh"
  done
fi

# GPG aliases
if command -v gpg >/dev/null 2>&1; then
  for _module in \
    gpg-keys \
    gpg-crypto \
    gpg-keyserver \
    gpg-trust; do
    # shellcheck source=/dev/null
    [[ -f "${_SECURITY_ALIASES_DIR}/${_module}.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/${_module}.aliases.sh"
  done
fi

# SSH aliases
if command -v ssh >/dev/null 2>&1; then
  for _module in \
    ssh-keys \
    ssh-config \
    ssh-tunnels; do
    # shellcheck source=/dev/null
    [[ -f "${_SECURITY_ALIASES_DIR}/${_module}.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/${_module}.aliases.sh"
  done
fi

# UFW aliases (Linux-only)
if [[ "${OSTYPE:-}" == linux* ]] && command -v ufw >/dev/null 2>&1 && [[ "${_DOTFILES_SECURITY_MODE}" == "strict" ]]; then
  # shellcheck source=/dev/null
  [[ -f "${_SECURITY_ALIASES_DIR}/ufw-rules.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/ufw-rules.aliases.sh"
fi

# Crypto utilities (checksums, password generation)
# shellcheck source=/dev/null
[[ -f "${_SECURITY_ALIASES_DIR}/crypto-utils.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/crypto-utils.aliases.sh"

# Nmap scanning
if command -v nmap >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  [[ -f "${_SECURITY_ALIASES_DIR}/nmap-scanning.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/nmap-scanning.aliases.sh"
fi

# Security audit tools (lynis, fail2ban)
# shellcheck source=/dev/null
[[ -f "${_SECURITY_ALIASES_DIR}/security-audit.aliases.sh" ]] && source "${_SECURITY_ALIASES_DIR}/security-audit.aliases.sh"

unset _module _SECURITY_ALIASES_DIR _DOTFILES_SECURITY_MODE
