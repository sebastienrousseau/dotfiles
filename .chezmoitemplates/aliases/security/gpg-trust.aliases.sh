# shellcheck shell=bash
# Copyright (c) 2015-2026 . All rights reserved.
# GPG Fingerprints, Trust & Cleanup
[[ -n "${_GPG_TRUST_LOADED:-}" ]] && return 0
_GPG_TRUST_LOADED=1

alias gpgfp='gpg --fingerprint'
alias gpgcheck='gpg --check-signatures'
alias gpgsig='gpg --list-signatures'

gpgtrust() {
  [[ -z "$1" ]] && {
    echo "Usage: gpgtrust <key_id>"
    return 1
  }
  gpg --edit-key "$1" trust quit
}

gpgclean() {
  # Deletes expired keys from keyring using machine-readable output
  local expired_keys=()
  while IFS=: read -r type _ _ _ keyid _ _ _ _ _ _ flags _; do
    if [[ "$type" == "pub" && "$flags" == *e* ]]; then
      expired_keys+=("$keyid")
    fi
  done < <(gpg --list-keys --with-colons 2>/dev/null)

  if [[ ${#expired_keys[@]} -eq 0 ]]; then
    echo "No expired keys found."
    return 0
  fi

  echo "Found ${#expired_keys[@]} expired key(s). Deleting..."
  for keyid in "${expired_keys[@]}"; do
    gpg --batch --yes --delete-keys "$keyid" && echo "Deleted key: $keyid"
  done
}
