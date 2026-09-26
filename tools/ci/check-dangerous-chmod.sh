#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# check-dangerous-chmod.sh — block `chmod 777` / `chmod 666` patterns
# from landing in shell scripts.
#
# Invoked as a pre-commit local hook (no filename args; scans the repo).
# Extracted from `config/pre-commit-config.yaml` under #866.
# =============================================================================

set -euo pipefail

# chmod anywhere in a command line (after sudo, &&, ;, a subshell ...), any
# flags, optional leading 0. Sticky/setuid forms (1777, 2777) are not matched.
PATTERN='(^|[;&|({[:space:]])chmod([[:space:]]+-[[:alpha:]]+)*[[:space:]]+0?(777|666)([^0-9]|$)'
EXCLUDES=(
  --exclude=check-dangerous-chmod.sh
  --exclude=test_check_dangerous_chmod.sh
  --exclude-dir=.git
  --exclude-dir=tests
)

if grep -rn \
  --include='*.sh' \
  --include='*.bash' \
  --include='*.zsh' \
  "${EXCLUDES[@]}" \
  -E "$PATTERN" . 2>/dev/null | grep -v '^Binary' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'; then
  echo "ERROR: Dangerous chmod patterns found (777 or 666)." >&2
  echo "Use the minimum permissions actually required; document any exception." >&2
  exit 1
fi
