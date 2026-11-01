#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

LOG_DIR="${HOME}/.local/share"
LOG_FILE="${LOG_DIR}/dotfiles.log"
MAX_SIZE_BYTES=$((1024 * 1024))
ROTATIONS=3

# shift_copy N: copy N of the installer log becomes copy N+1, gzipped.
shift_copy() {
  local from="${LOG_FILE}.$1" to="${LOG_FILE}.$(($1 + 1))"
  if [[ -f "$from.gz" ]]; then
    mv "$from.gz" "$to.gz"
  elif [[ -f "$from" ]]; then
    mv "$from" "$to"
    gzip -f "$to"
  fi
}

# rotate_installer_log: the installer's log, ~/.local/share/dotfiles.log,
# rotates by size, keeping ROTATIONS gzipped copies.
rotate_installer_log() {
  local i
  [[ -f "${LOG_FILE}" && "$(wc -c <"${LOG_FILE}" | tr -d ' ')" -ge "${MAX_SIZE_BYTES}" ]] || return 0
  for ((i = ROTATIONS; i >= 1; i--)); do shift_copy "$i"; done
  mv "${LOG_FILE}" "${LOG_FILE}.1"
  gzip -f "${LOG_FILE}.1"
  : >"${LOG_FILE}"
}

# The log.v1 logs ($XDG_STATE_HOME/dot/<domain>/log.jsonl) keep
# DOT_LOG_RETENTION_DAYS (30) days of records.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/dot/log.sh
source "$ROOT/lib/dot/log.sh"
dot_log_prune
rotate_installer_log
