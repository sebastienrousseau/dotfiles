#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/smoke-test.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "smoke_test_exists"
assert_file_exists "$TEST_SCRIPT" "smoke-test.sh should exist"

test_start "smoke_test_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "smoke_test_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TEST_SCRIPT"

# ── A missing tool must not end the run ──────────────────────────────
# The script runs under `set -e`; verify_cmd used to return 1 for an
# absent tool, so on a host without zsh (the ubuntu runners) the run
# stopped at the second check with no summary. Hide zsh, give chezmoi a
# silent stub: every tool must still be reported and the summary must
# carry the counts, with exit 1.
test_start "smoke_test_reports_every_tool_when_one_is_missing"
SMOKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/smoke-bin.XXXXXX")"
for tool in bash sh git grep sed awk head cat tr mktemp tput uname dirname basename printf date; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$SMOKE_BIN/$tool"
done
printf '#!/bin/sh\nexit 0\n' >"$SMOKE_BIN/chezmoi"
chmod +x "$SMOKE_BIN/chezmoi"
smoke_rc=0
smoke_out="$(PATH="$SMOKE_BIN" NO_COLOR=1 DOTFILES_NO_TUI=1 bash "$TEST_SCRIPT" 2>&1)" || smoke_rc=$?
rm -rf "$SMOKE_BIN"
assert_equals "1" "$smoke_rc" "a failing smoke run exits 1"
assert_true "grep -qE 'zsh +not found' <<<\"\$smoke_out\"" "the missing tool is reported"
assert_true "grep -qE 'chezmoi +output mismatch' <<<\"\$smoke_out\"" "checks after the missing tool still run"
assert_true "grep -qE '[0-9]+ failed +[0-9]+ passed' <<<\"\$smoke_out\"" "the summary line is printed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
