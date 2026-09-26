#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot lint command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

LINT_FILE="$REPO_ROOT/scripts/dot/commands/lint.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: lint.sh file exists
test_start "lint_cmd_file_exists"
assert_file_exists "$LINT_FILE" "lint.sh should exist"

# Test: lint.sh is valid shell syntax
test_start "lint_cmd_syntax_valid"
if bash -n "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lint.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint.sh has syntax errors"
fi

# Test: shellcheck invocation present
test_start "lint_cmd_has_shellcheck"
if grep -q "shellcheck" "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: references shellcheck"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reference shellcheck"
fi

# Test: shfmt invocation present
test_start "lint_cmd_has_shfmt"
if grep -q "shfmt" "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: references shfmt"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reference shfmt"
fi

# Test: --fix flag supported
test_start "lint_cmd_supports_fix"
if grep -q '\-\-fix' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports --fix flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support --fix flag"
fi

# Test: -f flag supported
test_start "lint_cmd_supports_short_fix"
if grep -qE '\-\-fix[[:space:]]+\|[[:space:]]+\-f' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports -f flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support -f flag"
fi

# Test: --check flag supported
test_start "lint_cmd_supports_check"
if grep -q '\-\-check' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports --check flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support --check flag"
fi

# Test: -c flag supported
test_start "lint_cmd_supports_short_check"
if grep -qE '\-\-check[[:space:]]+\|[[:space:]]+\-c' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports -c flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support -c flag"
fi

# Stub shellcheck/shfmt record their argv, so the flags the command really
# passes are checked rather than the text of lint.sh.
LINT_TMP="$DOTFILES_COV_TMPDIR/lint-flags"
mkdir -p "$LINT_TMP/bin"
for tool in shellcheck shfmt; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/%s.args"\n' "$LINT_TMP" "$tool" >"$LINT_TMP/bin/$tool"
  chmod +x "$LINT_TMP/bin/$tool"
done
PATH="$LINT_TMP/bin:$PATH" bash "$LINT_FILE" --check >/dev/null 2>&1 || true

test_start "lint_cmd_uses_project_shellcheck_flags"
assert_contains "-f gcc --severity=error -e SC1091 -e SC2030 -e SC2031 " "$(head -n 1 "$LINT_TMP/shellcheck.args" 2>/dev/null)" "shellcheck gets the CI flags"

test_start "lint_cmd_uses_project_shfmt_flags"
assert_contains "-i 2 -ci -l " "$(head -n 1 "$LINT_TMP/shfmt.args" 2>/dev/null)" "shfmt gets -i 2 -ci"

# Test: no hardcoded paths
test_start "lint_cmd_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: lint is registered in dot CLI dispatch
test_start "lint_cmd_registered_in_dispatch"
if grep -q 'lint' "$REPO_ROOT/bin/dot" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lint registered in dot CLI dispatch"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint should be registered in dot CLI dispatch"
fi

echo ""
echo "Lint command tests completed."
# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$LINT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
