#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# `dot attest --verify` runs the `lib/wasm-tools` module as WebAssembly and
# checks the evidence record against policy. These tests execute the module
# for real when a runtime and a build are available, and always check the
# wiring that does not need one.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/attest-verify.sh"
ATTEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/workstation-attestation.sh"
DOT_CLI="$REPO_ROOT/bin/dot"
FIXTURES="$REPO_ROOT/lib/wasm-tools/tests/data"
MODULE="${DOT_SYS_WASM:-$REPO_ROOT/lib/wasm-tools/target/wasm32-wasip1/release/dot-sys.wasm}"
WASMTIME_BIN="${WASMTIME:-wasmtime}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

pass_test() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $1"
}

fail_test() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

# ── Wiring, checkable without a WebAssembly runtime ────────────────────────

test_start "attest_verify_exists"
assert_file_exists "$TEST_SCRIPT" "attest-verify.sh should exist"

test_start "attest_verify_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "attest_verify_flag_aliases"
assert_file_contains "$TEST_SCRIPT" "--json | -j" "attest-verify supports -j"
assert_file_contains "$TEST_SCRIPT" "--max-age | -a" "attest-verify supports -a"
assert_file_contains "$TEST_SCRIPT" "--verify | -V" "attest-verify accepts -V"

test_start "attest_registers_verify"
assert_file_contains "$ATTEST_SCRIPT" "--verify | -V" "dot attest supports --verify"
assert_file_contains "$ATTEST_SCRIPT" "attest-verify.sh" "dot attest calls the verifier"
assert_file_contains "$DOT_CLI" "--verify|-V" "dot CLI documents --verify"

test_start "attest_verify_rejects_unknown_options"
assert_exit_code 2 "bash '$TEST_SCRIPT' --nonsense </dev/null"

test_start "attest_verify_rejects_missing_file"
assert_exit_code 2 "bash '$TEST_SCRIPT' /nonexistent/evidence.json </dev/null"

test_start "attest_verify_reports_a_missing_runtime"
output=$(WASMTIME=definitely-not-a-runtime bash "$TEST_SCRIPT" \
  "$FIXTURES/compliant.json" 2>&1 </dev/null || true)
if [[ "$output" == *"no WebAssembly runtime"* ]]; then
  pass_test "a missing runtime is reported, not ignored"
else
  fail_test "expected a missing-runtime diagnostic, got: $output"
fi

test_start "attest_verify_reports_a_missing_module"
output=$(DOT_SYS_WASM=/nonexistent/dot-sys.wasm bash "$TEST_SCRIPT" \
  "$FIXTURES/compliant.json" 2>&1 </dev/null || true)
if [[ "$output" == *"missing file"* || "$output" == *"no WebAssembly runtime"* ]]; then
  pass_test "a missing module is reported, not ignored"
else
  fail_test "expected a missing-module diagnostic, got: $output"
fi

# ── Real execution, when the module and a runtime are both present ─────────

if [[ -f "$MODULE" ]] && command -v "$WASMTIME_BIN" >/dev/null 2>&1; then
  test_start "attest_verify_passes_compliant_evidence"
  output=$(bash "$TEST_SCRIPT" --json --max-age any "$FIXTURES/compliant.json" 2>&1)
  status=$?
  if [[ $status -eq 0 ]] && [[ "$output" == *'"status": "ok"'* ]] && [[ "$output" == *'"engine": "wasm"'* ]]; then
    pass_test "the module verified compliant evidence and reported engine wasm"
  else
    fail_test "expected an ok/wasm verdict (exit $status): $output"
  fi

  test_start "attest_verify_fails_non_compliant_evidence"
  status=0
  output=$(bash "$TEST_SCRIPT" --json --max-age any "$FIXTURES/non-compliant.json" 2>&1) || status=$?
  if [[ $status -eq 1 ]] && [[ "$output" == *'"status": "failed"'* ]] && [[ "$output" == *'"path": "git_signing.format", "outcome": "fail"'* ]]; then
    pass_test "the module rejected non-compliant evidence with a named check"
  else
    fail_test "expected a failed verdict (exit $status): $output"
  fi

  test_start "attest_verify_rejects_input_that_is_not_json"
  status=0
  output=$(printf 'definitely not json' | bash "$TEST_SCRIPT" --json 2>&1) || status=$?
  if [[ $status -eq 2 ]] && [[ "$output" == *"expected a JSON value at byte 0"* ]]; then
    pass_test "malformed evidence is a usage error, not a verdict"
  else
    fail_test "expected exit 2 and a byte offset (exit $status): $output"
  fi

  test_start "attest_verify_runs_over_this_machine"
  # `dot attest` itself needs jq and the diagnostics tree; when it cannot
  # produce evidence there is nothing for the verifier to check, and that is
  # a fault in the producer rather than in this script.
  evidence=""
  if command -v jq >/dev/null 2>&1; then
    evidence=$(REPO_ROOT="$REPO_ROOT" bash "$ATTEST_SCRIPT" --json 2>/dev/null || true)
  fi
  if [[ "$evidence" != \{* ]]; then
    printf '%b\n' "  ${YELLOW}!${NC} $CURRENT_TEST: dot attest produced no evidence here; skipped"
  else
    status=0
    output=$(REPO_ROOT="$REPO_ROOT" bash "$DOT_CLI" attest --verify --json 2>/dev/null) || status=$?
    if [[ "$output" == *'"engine": "wasm"'* ]] && [[ "$output" == *'"path": "generated_at"'* ]]; then
      pass_test "dot attest --verify produced a WebAssembly verdict (exit $status)"
    else
      fail_test "expected a wasm verdict from dot attest --verify: $output"
    fi
  fi
else
  test_start "attest_verify_execution_skipped"
  printf '%b\n' "  ${YELLOW}!${NC} $CURRENT_TEST: no module at $MODULE or no $WASMTIME_BIN; execution checks skipped"
fi

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
