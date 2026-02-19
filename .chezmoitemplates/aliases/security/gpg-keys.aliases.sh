# shellcheck shell=bash
# GPG Key Management
[[ -n "${_GPG_KEYS_LOADED:-}" ]] && return 0
_GPG_KEYS_LOADED=1

alias gpgk='gpg --list-keys'
alias gpgka='gpg --list-keys --with-colons'
alias gpgks='gpg --list-secret-keys'
alias gpgksa='gpg --list-secret-keys --with-colons'
alias gpggen='gpg --full-generate-key'
alias gpgexport='gpg --export --armor'
alias gpgexports='gpg --export-secret-keys --armor'
alias gpgimp='gpg --import'
alias gpgdel='gpg --delete-key'
alias gpgdels='gpg --delete-secret-key'
alias gpgrenew='gpg --edit-key'
alias gpgver='gpg --version'
alias gpgminexp='gpg --export-options export-minimal --export'
