#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The pre-commit audit runs ShellCheck (errors only) on staged .sh files:
# an error fails it, a clean script passes, and no .sh file skips the step.
# Runs the audit in a throwaway repository.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AUDIT="$REPO_ROOT/scripts/git-hooks/pre-commit-audit.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/audit-sc.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# audit_shellcheck FILE CONTENT: stage FILE with CONTENT in a fresh repo and
# print the result of the audit's ShellCheck step (PASSED, FAILED, SKIPPED).
audit_shellcheck() {
  local repo
  repo="$(mktemp -d "$WORK/repo-XXXXXX")"
  git init -q "$repo"
  printf '%b' "$2" >"$repo/$1"
  git -C "$repo" add "$1"
  (cd "$repo" && bash "$AUDIT" 2>&1) | sed -n 's/.*Running ShellCheck\.\.\. *//p' |
    sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1 | tr -d '\\n'
}

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "  (skip) shellcheck not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

test_start "a_shellcheck_error_fails"
assert_equals "FAILED" "$(audit_shellcheck bad.sh '#!/usr/bin/env bash\nif true; then\n  echo x\n')" \
  "an unterminated if fails"

test_start "a_clean_script_passes"
assert_equals "PASSED" "$(audit_shellcheck good.sh '#!/usr/bin/env bash\necho ok\n')" "a clean script passes"

test_start "no_shell_file_skips"
assert_equals "SKIPPED" "$(audit_shellcheck notes.txt 'plain text\n')" "nothing to check"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
