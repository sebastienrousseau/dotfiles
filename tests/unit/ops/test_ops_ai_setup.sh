#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/ai-setup.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "ai_setup_exists"
assert_file_exists "$TEST_SCRIPT" "ai-setup.sh should exist"

test_start "ai_setup_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

# Without a terminal, a --version probe runs and a login is skipped.
test_start "ai_setup_probes_versions_and_skips_logins"
ai_bin="$DOTFILES_COV_TMPDIR/ai-bin"
ai_log="$DOTFILES_COV_TMPDIR/ai.log"
mkdir -p "$ai_bin"
for tool in copilot kiro-cli; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n' "$tool" "$ai_log" >"$ai_bin/$tool"
  chmod +x "$ai_bin/$tool"
done
ai_rc=0
ai_out="$(PATH="$ai_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" bash "$TEST_SCRIPT" </dev/null 2>&1)" || ai_rc=$?
assert_equals "0" "$ai_rc" "a missing tool does not fail the run"
assert_equals "copilot --version" "$(cat "$ai_log" 2>&1)" "only the version probe ran"
assert_contains "non-interactive shell; skipping login. Run 'kiro-cli login'" "$ai_out" "the login is named, not run"
assert_contains "Binary not found" "$ai_out" "a missing tool is reported"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
