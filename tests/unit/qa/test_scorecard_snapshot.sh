#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Test: scripts/qa/scorecard-snapshot.sh
#
# Verifies the snapshot script is syntactically valid, accepts
# the documented flags, and refuses unknown ones.
#
# Network-dependent assertions are SKIPPED — the script fetches
# api.scorecard.dev which CI runners may not reach.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
SCRIPT="$REPO_ROOT/scripts/qa/scorecard-snapshot.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  ✓ %s\n' "$1"
}
_fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  ✗ %s — %s\n' "$1" "$2"
}

[[ -x "$SCRIPT" ]] || {
  _fail "script_exists" "not found"
  printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  exit 1
}
_pass "script_exists"

if bash -n "$SCRIPT" 2>/dev/null; then
  _pass "syntax_valid"
else
  _fail "syntax_valid" "bash -n failed"
fi

if bash "$SCRIPT" --help 2>&1 | grep -q 'Fetch'; then
  _pass "help_flag_works"
else
  _fail "help_flag_works" "no Fetch line in help"
fi

if ! bash "$SCRIPT" --invalid-flag 2>/dev/null; then
  _pass "rejects_invalid_flag"
else
  _fail "rejects_invalid_flag" "should exit non-zero"
fi

if command -v jq >/dev/null 2>&1; then
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/bin" "$fixture/docs/security"
  cat >"$fixture/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' '{"score":9.8,"date":"2026-08-05","checks":[{"name":"Pinned-Dependencies","score":10,"reason":"All | dependencies pinned"}]}'
EOF
  chmod +x "$fixture/bin/curl"
  printf '# Scorecard\n\n## Live score\n\nNarrative stays.\n' >"$fixture/docs/security/SCORECARD.md"

  test_start_name="writes_snapshot_from_verified_payload"
  if REPO_ROOT="$fixture" PATH="$fixture/bin:$PATH" bash "$SCRIPT" >/dev/null; then
    if grep -q 'Aggregate score \*\*9.8 / 10\*\*' "$fixture/docs/security/SCORECARD.md"; then
      _pass "$test_start_name"
    else
      _fail "$test_start_name" "aggregate score missing from generated snapshot"
    fi
  else
    _fail "$test_start_name" "snapshot write failed"
  fi

  if REPO_ROOT="$fixture" PATH="$fixture/bin:$PATH" bash "$SCRIPT" --check >/dev/null; then
    _pass "check_accepts_current_snapshot"
  else
    _fail "check_accepts_current_snapshot" "fresh snapshot reported drift"
  fi

  sed -i.bak 's/Aggregate score \*\*9\.8/Aggregate score **1.0/' \
    "$fixture/docs/security/SCORECARD.md"
  rm -f "$fixture/docs/security/SCORECARD.md.bak"
  if REPO_ROOT="$fixture" PATH="$fixture/bin:$PATH" bash "$SCRIPT" --check >/dev/null; then
    _fail "check_rejects_stale_snapshot" "modified snapshot was accepted"
  else
    _pass "check_rejects_stale_snapshot"
  fi
  rm -rf "$fixture"
fi

# Keep child stderr attached so the coverage runner can see child xtrace lines.
bash "$SCRIPT" --help >/dev/null
bash "$SCRIPT" --invalid-flag >/dev/null || true

printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
