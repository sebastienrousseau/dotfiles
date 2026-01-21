#!/usr/bin/env bash

# run_before_00-audit.sh
# Logs every chezmoi execution to a local audit file.
# This complies with the "Audit Logging" requirement from PR #59.

set -euo pipefail

AUDIT_LOG="${HOME}/.dotfiles_audit.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
USER_NAME="${USER:-$(whoami)}"
HOST_NAME="${HOSTNAME:-$(hostname)}"

# Log the event
echo "[${TIMESTAMP}] User: ${USER_NAME}@${HOST_NAME} | Action: chezmoi apply | Status: Started" >> "${AUDIT_LOG}"
