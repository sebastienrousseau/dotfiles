#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# check-dangerous-chmod.sh — block `chmod 777` / `chmod 666` patterns
# from landing in shell scripts.
#
# Invoked as a pre-commit local hook (no filename args; scans the repo).
# Extracted from `config/pre-commit-config.yaml` under #866.
# =============================================================================

set -euo pipefail

PATTERN='^[[:space:]]*chmod[[:space:]]+(-R[[:space:]]+)?(777|666)'

if grep -rn --include='*.sh' -E "$PATTERN" . 2>/dev/null | grep -v '^Binary'; then
  echo "ERROR: Dangerous chmod patterns found (777 or 666)." >&2
  echo "Use the minimum permissions actually required; document any exception." >&2
  exit 1
fi
