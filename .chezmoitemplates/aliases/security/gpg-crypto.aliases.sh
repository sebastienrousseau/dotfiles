# shellcheck shell=bash
# GPG Encryption & Decryption, Signing & Verification
[[ -n "${_GPG_CRYPTO_LOADED:-}" ]] && return 0
_GPG_CRYPTO_LOADED=1

# Encryption & Decryption
function gpgencrypt() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: gpgencrypt <recipient> <file>"
    return 1
  }
  gpg --encrypt --recipient "$1" "$2"
}

function gpgesign() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: gpgesign <recipient> <file>"
    return 1
  }
  gpg --encrypt --sign --recipient "$1" "$2"
}

alias gpgsym='gpg --symmetric'
alias gpgdec='gpg --decrypt'
alias gpgdecfiles='gpg --decrypt-files'

# Signing & Verification
alias gpgsign='gpg --sign'
alias gpgclear='gpg --clearsign'
alias gpgdetach='gpg --detach-sign'
alias gpgdetacha='gpg --detach-sign --armor'
alias gpgverify='gpg --verify'
alias gpgverifyf='gpg --verify-files'
