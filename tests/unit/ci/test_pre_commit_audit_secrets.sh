#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The pre-commit audit's secret scan flags a credential-named key that is
# assigned a value, and not a shell parameter expansion of one
# (${API_KEY:-}, ${API_KEY:=x}), a Python condition (if not API_KEY:) or a
# value taken from a variable or a call, which made every commit touching
# dot-ai-proxy or dot-ai-serve fail.
# The fake values are short runs of x: a literal to the audit, nothing for
# gitleaks or secret-governance.sh to call a leak. Runs the audit in a
# throwaway repository.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AUDIT="$REPO_ROOT/scripts/git-hooks/pre-commit-audit.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/audit-secrets.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# audit_secrets FILE CONTENT: stage FILE with CONTENT in a fresh repo and
# print the result of the audit's secret scan (PASSED or FAILED).
audit_secrets() {
  local repo="$WORK/repo-$RANDOM"
  git init -q "$repo"
  printf '%s\n' "$2" >"$repo/$1"
  git -C "$repo" add "$1"
  (cd "$repo" && bash "$AUDIT" 2>&1) | sed -n 's/.*Scanning for secrets\.\.\. *//p' |
    sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1 | tr -d '\\n'
}

test_start "an_assigned_secret_fails"
assert_equals "FAILED" "$(audit_secrets run.sh 'export API_KEY=xxxxxx')" "shell assignment"
assert_equals "FAILED" "$(audit_secrets run.sh 'GITHUB_TOKEN = "xxxxxx"')" "assignment with spaces"
assert_equals "FAILED" "$(audit_secrets conf.yml 'password: hunter2')" "a YAML value"
assert_equals "FAILED" "$(audit_secrets conf.json '"api_key":"abc123"')" "a JSON value"

test_start "a_reference_to_a_secret_passes"
assert_equals "PASSED" "$(audit_secrets run.sh 'if [[ -z "${DOT_AI_API_KEY:-}" ]]; then')" "a :- default"
assert_equals "PASSED" "$(audit_secrets run.sh ': "${API_KEY:=}"')" "a := default"
assert_equals "PASSED" "$(audit_secrets serve.py 'if not API_KEY:  # fail closed')" "a Python condition"

test_start "a_secret_taken_from_a_variable_or_a_call_passes"
assert_equals "PASSED" "$(audit_secrets run.sh 'export OPENAI_API_KEY="$key"')" "a shell variable"
assert_equals "PASSED" "$(audit_secrets run.sh 'export API_KEY=${KEY}')" "a braced shell variable"
assert_equals "PASSED" "$(audit_secrets serve.py 'API_KEY = os.environ.get("DOT_AI_API_KEY", "")')" "an environment lookup"
assert_equals "PASSED" "$(audit_secrets serve.py '        API_KEY = load_or_create_token()')" "a call"
assert_equals "FAILED" "$(audit_secrets serve.py 'API_KEY = "xxxxxx"')" "but a literal still fails"
assert_equals "FAILED" "$(audit_secrets run.sh 'A=$x; API_KEY="xxxxxx"')" "even beside a variable"

# audit_status FILE CONTENT: stage FILE with CONTENT in a fresh repo and
# print the whole audit's exit status. The scan's verdict must decide it:
# a clean file passes the audit, a written-down secret fails it.
audit_status() {
  local repo="$WORK/repo-$RANDOM" rc=0
  git init -q "$repo"
  printf '%s\n' "$2" >"$repo/$1"
  git -C "$repo" add "$1"
  (cd "$repo" && bash "$AUDIT" >/dev/null 2>&1) || rc=$?
  printf '%s' "$rc"
}

test_start "the_scan_verdict_decides_the_audit_exit"
assert_equals "0" "$(audit_status notes.txt 'nothing to see here')" "a clean file passes the audit"
assert_equals "1" "$(audit_status conf.yml 'password: hunter2')" "a written-down secret fails the audit"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
