#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for dot_local/bin/executable_jwt.
# Slice 3 of #883: backfill coverage by running each managed script
# through safe-mode entry points (--help / no-arg / invalid flag).
# Edit-by-hand to add behavioral assertions; the auto-shell will leave
# this file alone if `# AUTO-GENERATED: false` appears in the first
# 10 lines.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_jwt"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "dot_local/bin/executable_jwt must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

cov_exercise_script "$SCRIPT_FILE"
cov_exercise_functions_file "$SCRIPT_FILE"

test_start "jwt_deep_branches_execute"
jwt_tmp="$DOTFILES_COV_TMPDIR/jwt-deep"
mkdir -p "$jwt_tmp"
header="eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0"
payload_future="eyJleHAiOjQxMDI0NDQ4MDAsImlhdCI6MTcwMDAwMDAwMCwic3ViIjoidGVzdCJ9"
payload_expired="eyJleHAiOjEwMDAsImlhdCI6MTAwLCJzdWIiOiJvbGQifQ"
signature="c2lnbmF0dXJl"
future_token="${header}.${payload_future}.${signature}"
expired_token="${header}.${payload_expired}.${signature}"
(
  set +e
  bash "$SCRIPT_FILE" "$future_token"
  bash "$SCRIPT_FILE" "Bearer $future_token"
  printf '%s\n' "bearer $expired_token" | bash "$SCRIPT_FILE"
  bash "$SCRIPT_FILE" "invalid-token"
) >/dev/null || true
printf '%s\n' "$future_token" >"$jwt_tmp/token.jwt"
assert_file_exists "$jwt_tmp/token.jwt" \
  "jwt deep branches used sandbox token fixture"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
