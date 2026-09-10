#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The branches of apihealth that need the network, or need it absent.
#
# The existing suite can only assert on failures: a real request to a real URL
# would make the test depend on the internet, so the success arm — and with it
# the "all checks passed" verdict — had never run. A curl stub that prints a
# status code removes the network from the question entirely.
#
# The same stub directory, emptied, reaches the "curl is not installed" guard,
# which is otherwise unreachable on any machine that has curl.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/api/apihealth.sh"

WORK="$(mktemp -d -t apihealth.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

source "$FUNC_FILE"

dot_fixture_basebin "$WORK/base"
mkdir -p "$WORK/withcurl" "$WORK/nocurl"

# A curl that reports whatever status the case wants, without a network.
ah_curl() {
  printf '#!/bin/sh\nprintf "%%s" "%s"\nexit 0\n' "$1" >"$WORK/withcurl/curl"
  chmod +x "$WORK/withcurl/curl"
}

AH_OUT=""
AH_RC=0
# ah_run <bin-dir> [args...] — call apihealth with a PATH holding only the
# base tools plus <bin-dir>.
ah_run() {
  local bindir="$1"
  shift
  AH_RC=0
  AH_OUT="$(PATH="$bindir:$WORK/base" apihealth "$@" 2>&1)" || AH_RC=$?
}

# ── 1. A healthy endpoint ──────────────────────────────────────────────────
test_start "apihealth_reports_a_healthy_endpoint"
ah_curl 200
ah_run "$WORK/withcurl" "https://example.invalid/health"
assert_equals "0" "$AH_RC" "a matching status code should pass"
assert_contains "API is healthy (Status: 200)" "$AH_OUT" \
  "the healthy result should name the status it saw"

test_start "apihealth_reports_the_overall_verdict"
assert_contains "All API health checks passed successfully" "$AH_OUT" \
  "a clean run should end with the passing verdict"

test_start "apihealth_honours_an_expected_status"
ah_curl 204
ah_run "$WORK/withcurl" --expect 204 "https://example.invalid/health"
assert_equals "0" "$AH_RC" "an explicitly expected status should pass"

test_start "apihealth_fails_on_an_unexpected_status"
ah_curl 503
ah_run "$WORK/withcurl" "https://example.invalid/health"
assert_equals "1" "$AH_RC" "a mismatched status should fail"
assert_contains "Some API health checks failed" "$AH_OUT" \
  "a failing run should end with the failing verdict"

# ── 2. Options that take a value need one ──────────────────────────────────
test_start "apihealth_header_requires_a_value"
ah_curl 200
ah_run "$WORK/withcurl" --header
assert_equals "1" "$AH_RC" "--header with nothing after it should fail"
assert_contains "--header requires a non-empty option argument" "$AH_OUT" \
  "the failure should name the option"

test_start "apihealth_timeout_requires_a_value"
ah_run "$WORK/withcurl" --timeout
assert_equals "1" "$AH_RC" "--timeout with nothing after it should fail"
assert_contains "--timeout requires a non-empty option argument" "$AH_OUT" \
  "the failure should name the option"

# ── 3. curl is a hard dependency ───────────────────────────────────────────
test_start "apihealth_requires_curl"
ah_run "$WORK/nocurl" "https://example.invalid/health"
assert_equals "1" "$AH_RC" "no curl at all should fail"
assert_contains "'curl' is not installed" "$AH_OUT" \
  "the failure should name the missing dependency"

print_summary
