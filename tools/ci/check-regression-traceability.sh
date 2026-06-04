#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# check-regression-traceability.sh — enforce a `# Regression for:` header on
# every file under `tests/regression/`, with one of three accepted forms:
#
#   # Regression for: GH-1234
#   # Regression for: <7-or-more-char-sha-prefix>
#   # Regression for: pre-history
#
# The first two are required for any test introduced as part of fixing a
# known issue or shipping a known commit. The third is an explicit "we
# couldn't trace it" marker — still trackable, just not auto-resolvable.
#
# Invocation:
#   * pre-commit local hook (files passed as args)
#   * standalone: ./tools/ci/check-regression-traceability.sh
# =============================================================================

set -euo pipefail

PATTERN='^# *Regression for: *(GH-[0-9]+|[0-9a-f]{7,40}|pre-history)\b'

check_one() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  # Only check files under tests/regression/
  case "$f" in
    tests/regression/*) ;;
    */tests/regression/*) ;;
    *) return 0 ;;
  esac

  if ! head -15 "$f" | grep -Eq "$PATTERN"; then
    echo "MISSING trace header: $f"
    return 1
  fi
}

fail=0
if [[ $# -gt 0 ]]; then
  for f in "$@"; do
    check_one "$f" || fail=1
  done
else
  while IFS= read -r f; do
    check_one "$f" || fail=1
  done < <(git ls-files "tests/regression/*.sh")
fi

if [[ $fail -ne 0 ]]; then
  cat >&2 <<'MSG'

Every file under tests/regression/ must include a trace header within
the first 15 lines, in one of these forms:

  # Regression for: GH-1234            (preferred — link to GitHub issue)
  # Regression for: <sha-prefix>       (link to introducing commit)
  # Regression for: pre-history        (no traceable origin)

Why: regressions pinned years ago without context are forensic dead-ends
when they fire. See docs/operations/TESTING.md and #868.

MSG
  exit 1
fi
