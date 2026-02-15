#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Log Rotate • Tools"

LOG_DIR="${HOME}/.local/share"
LOG_FILE="${LOG_DIR}/dotfiles.log"
MAX_SIZE_BYTES=$((1024 * 1024))
ROTATIONS=3

if [[ ! -f "${LOG_FILE}" ]]; then
  ui_info "No log file found."
  exit 0
fi

size=$(wc -c <"${LOG_FILE}" | tr -d ' ')
if [[ "${size}" -lt "${MAX_SIZE_BYTES}" ]]; then
  ui_info "Log size below threshold. No rotation needed."
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
: >"${LOG_FILE}"
ui_success "Rotated log file" "$LOG_FILE"
