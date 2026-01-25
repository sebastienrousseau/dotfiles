#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${HOME}/.local/share"
LOG_FILE="${LOG_DIR}/dotfiles.log"
MAX_SIZE_BYTES=$((1024 * 1024))
ROTATIONS=3

if [[ ! -f "${LOG_FILE}" ]]; then
  exit 0
fi

size=$(wc -c <"${LOG_FILE}" | tr -d ' ')
if [[ "${size}" -lt "${MAX_SIZE_BYTES}" ]]; then
  exit 0
fi

for i in $(seq ${ROTATIONS} -1 1); do
  if [[ -f "${LOG_FILE}.${i}.gz" ]]; then
    mv "${LOG_FILE}.${i}.gz" "${LOG_FILE}.$((i + 1)).gz"
  elif [[ -f "${LOG_FILE}.${i}" ]]; then
    mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
    gzip -f "${LOG_FILE}.$((i + 1))"
  fi
done

mv "${LOG_FILE}" "${LOG_FILE}.1"
gzip -f "${LOG_FILE}.1"
: > "${LOG_FILE}"
