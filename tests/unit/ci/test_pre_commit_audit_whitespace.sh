#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The pre-commit audit's formatting check flags trailing spaces and tabs in
# staged files, and not the carriage return of a CRLF line: .gitattributes
# checks *.ps1, *.bat and *.cmd out with CRLF, so every such file used to
# fail the audit. Runs the audit in a throwaway repository.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AUDIT="$REPO_ROOT/scripts/git-hooks/pre-commit-audit.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/audit-ws.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# audit_formatting FILE CONTENT: stage FILE with CONTENT in a fresh repo and
# print the result of the audit's formatting check (PASSED or FAILED).
audit_formatting() {
  local repo="$WORK/repo-$RANDOM"
  git init -q "$repo"
  printf '%b' "$2" >"$repo/$1"
  git -C "$repo" add "$1"
  (cd "$repo" && bash "$AUDIT" 2>&1) | sed -n 's/.*Checking formatting\.\.\. *//p' |
    sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1 | tr -d '\\n'
}

test_start "crlf_lines_are_not_trailing_whitespace"
assert_equals "PASSED" "$(audit_formatting completion.ps1 'Write-Output 1\r\nWrite-Output 2\r\n')" "a CRLF file passes"

test_start "trailing_space_still_fails"
assert_equals "FAILED" "$(audit_formatting notes.txt 'one \ntwo\n')" "a trailing space fails"
assert_equals "FAILED" "$(audit_formatting script.ps1 'one\t\r\ntwo\r\n')" "a trailing tab before CRLF fails"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
