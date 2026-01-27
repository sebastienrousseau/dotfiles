#!/usr/bin/env bash

# run_before_00-audit.sh
# Audit logging disabled by default.
# Enable by setting DOTFILES_AUDIT_LOG=1.

set -euo pipefail

if [[ "${DOTFILES_AUDIT_LOG:-0}" == "1" ]]; then
  AUDIT_LOG="${HOME}/.local/share/dotfiles.log"
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  USER_NAME="${USER:-$(whoami)}"
  HOST_NAME="${HOSTNAME:-$(hostname)}"

  # Log the event
  echo "[${TIMESTAMP}] User: ${USER_NAME}@${HOST_NAME} | Action: chezmoi apply | Status: Started" >>"${AUDIT_LOG}"
fi
