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

# The tools come from the roster: crush, which the hand-kept list never
# had, is checked too, and naming tools runs only those.
test_start "ai_setup_covers_every_roster_tool"
crush_log="$DOTFILES_COV_TMPDIR/crush.log"
printf '#!/usr/bin/env bash\necho "crush $*" >>"%s"\n' "$crush_log" >"$ai_bin/crush"
chmod +x "$ai_bin/crush"
PATH="$ai_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" bash "$TEST_SCRIPT" </dev/null >/dev/null 2>&1 || true
assert_equals "crush --version" "$(cat "$crush_log" 2>&1)" "a roster tool outside the old list is checked"

test_start "ai_setup_named_tools_only"
: >"$ai_log"
: >"$crush_log"
ai_out="$(PATH="$ai_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" bash "$TEST_SCRIPT" copilot </dev/null 2>&1)"
assert_equals "copilot --version" "$(cat "$ai_log" 2>&1)" "the named tool runs"
assert_equals "" "$(cat "$crush_log" 2>&1)" "the others do not"
assert_equals "no" "$([[ "$ai_out" == *"Kiro CLI"* ]] && echo yes || echo no)" "nor are they listed"

test_start "ai_setup_unknown_tool_is_a_usage_error"
ai_rc=0
ai_out="$(PATH="$ai_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" bash "$TEST_SCRIPT" nosuchtool </dev/null 2>&1)" || ai_rc=$?
assert_equals "2" "$ai_rc" "an unknown tool exits 2"
assert_contains "'nosuchtool' is not a roster tool" "$ai_out" "and is named"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
