#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Build a stub file whose helper calls a function that won't be defined
# at exercise time. cov_exercise_functions_file sources the file in a
# subshell with no other helpers in scope, so this reproduces the
# `require_source_dir: command not found` pattern we hit in
# scripts/dot/commands/*.sh.
stub_dir="$(mktemp -d -t cov-strict.XXXXXX)"
trap 'rm -rf "$stub_dir"' EXIT

stub_file="$stub_dir/cmd_with_missing_helper.sh"
cat >"$stub_file" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

_demo_helper() {
  # Calls a function that the harness will not have sourced — this is
  # the exact failure mode from agent.sh's _agent_repo_root chain.
  require_source_dir
}
STUB

# Run cov_exercise_functions_file in subshells so its internal
# TESTS_FAILED++ stays scoped — we observe its output instead of its
# counter state to avoid polluting our own pass/fail tally.
strict_out="$(DOT_STRICT=1 cov_exercise_functions_file "$stub_file" 2>&1)"
loose_out="$(DOT_STRICT=0 cov_exercise_functions_file "$stub_file" 2>&1)"

test_start "cov_strict_promotes_command_not_found"
if grep -q "DOT_STRICT violations" <<<"$strict_out"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: strict mode caught missing helper"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: strict mode missed the failure"
fi

test_start "cov_loose_tolerates_command_not_found"
if ! grep -q "DOT_STRICT violations" <<<"$loose_out"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: loose mode kept tolerant default"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: loose mode regressed to strict"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
