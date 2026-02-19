#!/usr/bin/env bash

# run_before_00-audit.sh
# Audit logging disabled by default.
# Enable by setting DOTFILES_AUDIT_LOG=1.
#
# Privacy: Uses hashed identifiers instead of plaintext username/hostname
# to comply with GDPR Art. 5(1)(f) and CCPA 1798.100(a).

set -euo pipefail

if [[ "${DOTFILES_AUDIT_LOG:-0}" == "1" ]]; then
  AUDIT_LOG="${HOME}/.local/share/dotfiles.log"
  mkdir -p "$(dirname "$AUDIT_LOG")"
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

  # Anonymize user identity with a salted hash (first 12 chars for readability)
  _raw_user="${USER:-$(whoami 2>/dev/null || echo unknown)}"
  _raw_host="${HOSTNAME:-$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo unknown)}"
  _salt="dotfiles-audit-$(date +%Y)"

  # Use sha256 to create anonymized identifier
  if command -v sha256sum >/dev/null 2>&1; then
    USER_ID=$(echo -n "${_salt}:${_raw_user}" | sha256sum | cut -c1-12)
    HOST_ID=$(echo -n "${_salt}:${_raw_host}" | sha256sum | cut -c1-12)
  elif command -v shasum >/dev/null 2>&1; then
    USER_ID=$(echo -n "${_salt}:${_raw_user}" | shasum -a 256 | cut -c1-12)
    HOST_ID=$(echo -n "${_salt}:${_raw_host}" | shasum -a 256 | cut -c1-12)
  else
    # Fallback: use simple hash if no sha tools available
    USER_ID="user-${#_raw_user}"
    HOST_ID="host-${#_raw_host}"
  fi

  # Log the event with anonymized identifiers
  echo "[${TIMESTAMP}] User: ${USER_ID}@${HOST_ID} | Action: chezmoi apply | Status: Started" >>"${AUDIT_LOG}"

  unset _raw_user _raw_host _salt
fi
