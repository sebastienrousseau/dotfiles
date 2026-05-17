# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# GPG Key Server Operations
[[ -n "${_GPG_KEYSERVER_LOADED:-}" ]] && return 0
_GPG_KEYSERVER_LOADED=1

alias gpgsearch='gpg --search-keys'
alias gpgserver='gpg --keyserver hkps://keys.openpgp.org'

gpgkrecv() {
  [[ -z "$1" ]] && {
    echo "Usage: gpgkrecv <key_id>"
    return 1
  }
  gpg --keyserver hkps://keys.openpgp.org --recv-keys "$1"
}

gpgksend() {
  [[ -z "$1" ]] && {
    echo "Usage: gpgksend <key_id>"
    return 1
  }
  gpg --keyserver hkps://keys.openpgp.org --send-keys "$1"
}

alias gpgkrefresh='gpg --keyserver hkps://keys.openpgp.org --refresh-keys'
