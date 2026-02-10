# shellcheck shell=bash
# Cryptographic Utilities (Checksums, Password Generation, File Encryption)
[[ -n "${_CRYPTO_UTILS_LOADED:-}" ]] && return 0
_CRYPTO_UTILS_LOADED=1

# Hashing Utilities (with fallback for macOS)
if command -v sha256sum >/dev/null 2>&1; then
  alias sha256='sha256sum'
  alias sha1='sha1sum'
  alias sha512='sha512sum'
  alias md5='md5sum'
elif command -v shasum >/dev/null 2>&1; then
  # macOS default
  alias sha256='shasum -a 256'
  alias sha1='shasum -a 1'
  alias sha512='shasum -a 512'
  alias md5='md5' # macOS has `md5` by default
fi

# Password Generation
if command -v pwgen >/dev/null 2>&1; then
  alias pwgen8='pwgen -s 8 1'
  alias pwgen12='pwgen -s 12 1'
  alias pwgen16='pwgen -s 16 1'
  alias pwgen20='pwgen -s 20 1'
  alias pwgen32='pwgen -s 32 1'
  alias pwgen64='pwgen -s 64 1'
fi

# File Encryption with ccrypt
if command -v ccrypt >/dev/null 2>&1; then
  alias cce='ccrypt -e'
  alias ccd='ccrypt -d'
  alias ccc='ccrypt -c'
fi
