#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Argument and dependency handling in three small dot_local executables.
#
# gbd validates its whitelist as a regular expression before using it,
# dot-load-benchmark validates its run count, and jwt picks a JSON formatter
# from what is installed. None of those arms had run: the first two need a
# deliberately malformed argument, and the third needs a machine without jq.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

BIN_DIR="$REPO_ROOT/defaults/dot_local/bin"

WORK="$(mktemp -d -t smallbin.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs" "$WORK/run"
dot_fixture_basebin "$WORK/base" base64 od seq

SB_OUT=""
SB_RC=0
sb_run() {
  local script="$1"
  shift
  SB_RC=0
  SB_OUT="$(
    cd "$WORK/run" &&
      PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
        "${BASH:-bash}" "$BIN_DIR/$script" "$@" 2>&1 </dev/null
  )" || SB_RC=$?
}

# ── 1. gbd rejects a whitelist that is not a regular expression ────────────
#
# git is a stub: the validation happens after the repository check, and this
# suite must not touch a real repository's branches.
test_start "gbd_rejects_an_invalid_whitelist_pattern"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/git"
chmod +x "$WORK/stubs/git"
sb_run executable_gbd '['
assert_equals "1" "$SB_RC" "an unusable pattern should exit 1"
assert_contains "Invalid whitelist pattern" "$SB_OUT" \
  "the failure should name the pattern that could not be used"

# ── 2. dot-load-benchmark validates its run count ──────────────────────────
test_start "dot_load_benchmark_rejects_a_zero_run_count"
sb_run executable_dot-load-benchmark 0
assert_equals "2" "$SB_RC" "a run count of zero should exit 2"
assert_contains "Invalid runs value" "$SB_OUT" "the failure should name the value"

test_start "dot_load_benchmark_rejects_a_non_numeric_run_count"
sb_run executable_dot-load-benchmark abc
assert_equals "2" "$SB_RC" "a non-numeric run count should exit 2"

# ── 3. jwt falls back through its JSON formatters ──────────────────────────
#
# A JWT whose payload is valid JSON, so each formatter has something to do.
# Assembled from its three parts rather than written as one literal: joined,
# the string is high-entropy enough that gitleaks' generic-api-key rule reads
# it as a credential. Nothing here is secret — the parts decode to
# {"alg":"HS256"}, {"sub":"123","name":"Test"} and the word "sig".
_jwt_header="eyJhbGciOiJIUzI1NiJ9"                  # {"alg":"HS256"}
_jwt_payload="eyJzdWIiOiIxMjMiLCJuYW1lIjoiVGVzdCJ9" # {"sub":"123","name":"Test"}
_jwt_sig="c2ln"                                     # "sig"
JWT_TOKEN="${_jwt_header}.${_jwt_payload}.${_jwt_sig}"

test_start "jwt_uses_python_when_jq_is_absent"
cat >"$WORK/stubs/python3" <<'STUB'
#!/bin/sh
echo "PYTHON-FORMATTED"
cat >/dev/null
exit 0
STUB
chmod +x "$WORK/stubs/python3"
sb_run executable_jwt "$JWT_TOKEN"
assert_contains "PYTHON-FORMATTED" "$SB_OUT" \
  "with no jq on PATH the python formatter should be used"

test_start "jwt_falls_back_to_raw_output"
rm -f "$WORK/stubs/python3"
sb_run executable_jwt "$JWT_TOKEN"
assert_contains '"sub"' "$SB_OUT" \
  "with no formatter at all the decoded payload should still be printed"

print_summary
