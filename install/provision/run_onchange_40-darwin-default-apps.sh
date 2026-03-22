#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

if ! command -v duti >/dev/null 2>&1; then
  echo "duti not installed; skipping default app bindings."
  exit 0
fi

DUTI_FILE="${HOME}/.config/duti/defaults.duti"
if [[ ! -f "${DUTI_FILE}" ]]; then
  echo "No duti defaults file found at ${DUTI_FILE}."
  exit 0
fi

duti "${DUTI_FILE}" || true
