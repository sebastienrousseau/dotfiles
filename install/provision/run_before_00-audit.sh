#!/usr/bin/env bash

# run_before_00-audit.sh
# Audit logging disabled by default.
# Enable by setting DOTFILES_AUDIT_LOG=1.

set -euo pipefail

if [[ "${DOTFILES_AUDIT_LOG:-0}" == "1" ]]; then
  AUDIT_LOG="${HOME}/.local/share/dotfiles.log"
  mkdir -p "$(dirname "$AUDIT_LOG")"
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  USER_NAME="${USER:-$(whoami 2>/dev/null || echo unknown)}"
  HOST_NAME="${HOSTNAME:-$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo unknown)}"

  # Log the event
  echo "[${TIMESTAMP}] User: ${USER_NAME}@${HOST_NAME} | Action: chezmoi apply | Status: Started" >>"${AUDIT_LOG}"
fi
