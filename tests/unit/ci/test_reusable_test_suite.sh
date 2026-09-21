#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORKFLOW="$REPO_ROOT/.github/workflows/reusable-test-suite.yml"

test_start "integration_lane_does_not_repeat_unit_regression_suite"
assert_file_contains "$WORKFLOW" \
  'RUN_INTEGRATION=1 ./tests/framework/test_runner.sh --jobs auto --integration-only' \
  "integration lane must select only integration tests"

test_start "unit_lane_remains_the_single_full_suite_invocation"
full_suite_count="$(
  grep -F './tests/framework/test_runner.sh --jobs auto 2>&1' "$WORKFLOW" | wc -l | tr -d ' '
)"
assert_equals 1 "$full_suite_count" \
  "reusable workflow must execute the full unit/regression suite once"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
