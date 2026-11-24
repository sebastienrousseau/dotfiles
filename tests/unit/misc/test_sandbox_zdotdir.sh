#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Each case sets ZDOTDIR inside its own $(...) subshell on purpose, so no
# sandbox leaks into the next case.
# shellcheck disable=SC2030,SC2031
# Test sandboxes drop the developer's ZDOTDIR. zsh reads its startup files
# from $ZDOTDIR before $HOME, so a sandbox that swaps HOME but keeps an
# exported ZDOTDIR runs the developer's real zshrc against the sandbox:
# under the feature matrix, health.sh's `zsh -i -c exit` did that and
# never returned, and the pre-push suite ran out of processes.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FW="$REPO_ROOT/tests/framework"

test_start "feature_matrix_sandbox_drops_zdotdir"
got="$(
  export ZDOTDIR=/nonexistent/developer/zsh
  source "$FW/feature_matrix_lib.sh" >/dev/null 2>&1
  fm_sandbox_setup >/dev/null 2>&1
  printf '%s' "${ZDOTDIR-unset}"
  fm_sandbox_teardown >/dev/null 2>&1
)"
assert_equals "unset" "$got" "fm_sandbox_setup unsets ZDOTDIR"

test_start "cmd_sandbox_drops_zdotdir"
got="$(
  export ZDOTDIR=/nonexistent/developer/zsh
  source "$FW/cmd_test_helpers.sh" >/dev/null 2>&1
  _cmd_sandbox_init >/dev/null 2>&1
  printf '%s' "${ZDOTDIR-unset}"
  rm -rf "${TMPHOME:?}"
)"
assert_equals "unset" "$got" "_cmd_sandbox_init unsets ZDOTDIR"

test_start "coverage_sandbox_drops_zdotdir"
got="$(
  export ZDOTDIR=/nonexistent/developer/zsh
  source "$FW/coverage_helpers.sh" >/dev/null 2>&1
  cov_setup_sandbox >/dev/null 2>&1
  printf '%s' "${ZDOTDIR-unset}"
)"
assert_equals "unset" "$got" "cov_setup_sandbox unsets ZDOTDIR"

test_start "runner_drops_zdotdir"
# Every test the runner starts inherits its environment, including those
# that swap HOME without one of the helpers above.
if grep -Eq '^[[:space:]]*unset[[:space:]]+([A-Z_]+[[:space:]]+)*ZDOTDIR\b' "$FW/test_runner.sh"; then
  runner=yes
else
  runner=no
fi
assert_equals "yes" "$runner" "test_runner.sh unsets ZDOTDIR before starting tests"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
