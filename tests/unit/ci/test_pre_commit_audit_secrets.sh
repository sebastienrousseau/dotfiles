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
  local repo
  repo="$(mktemp -d "$WORK/repo-XXXXXX")"
  git init -q "$repo"
  mkdir -p "$(dirname "$repo/$1")"
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
  local repo rc=0
  repo="$(mktemp -d "$WORK/repo-XXXXXX")"
  git init -q "$repo"
  printf '%s\n' "$2" >"$repo/$1"
  git -C "$repo" add "$1"
  (cd "$repo" && bash "$AUDIT" >/dev/null 2>&1) || rc=$?
  printf '%s' "$rc"
}

test_start "the_scan_verdict_decides_the_audit_exit"
assert_equals "0" "$(audit_status notes.txt 'nothing to see here')" "a clean file passes the audit"
assert_equals "1" "$(audit_status conf.yml 'password: hunter2')" "a written-down secret fails the audit"

# audit_change FILE OLD NEW: commit FILE as OLD (hooks off), stage it as
# NEW and print the secret scan's result.
audit_change() {
  local repo
  repo="$(mktemp -d "$WORK/repo-XXXXXX")"
  git init -q "$repo"
  printf '%s\n' "$2" >"$repo/$1"
  git -C "$repo" add "$1"
  git -C "$repo" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null commit -q -m old
  printf '%s\n' "$3" >"$repo/$1"
  git -C "$repo" add "$1"
  (cd "$repo" && bash "$AUDIT" 2>&1) | sed -n 's/.*Scanning for secrets\.\.\. *//p' |
    sed 's/\x1b\[[0-9;]*m//g' | cut -d' ' -f1 | tr -d '\\n'
}

test_start "only_the_lines_a_commit_adds_are_scanned"
assert_equals "PASSED" "$(audit_change conf.yml 'password: hunter2' "$(printf 'password: hunter2\nlevel: debug')")" \
  "a match already in the file is not this commit's"
assert_equals "FAILED" "$(audit_change conf.yml 'level: debug' "$(printf 'level: debug\npassword: hunter2')")" \
  "a match the commit adds still fails"
assert_equals "FAILED" "$(audit_change conf.yml 'level: debug' "$(printf 'level: debug\n++ password: hunter2')")" \
  "even on a line that starts like a diff header"

# detect-secrets keeps a SHA-1 of each finding in .secrets.baseline, under
# the key hashed_secret, and rewrites the file when it re-sorts it. The
# hash is not the secret, so the baseline is not scanned; the same line in
# any other file still is.
test_start "the_detect_secrets_baseline_is_not_scanned"
assert_equals "PASSED" "$(audit_secrets .secrets.baseline '        "hashed_secret": "0000000000000000000000000000000000000000",')" \
  "a hash in the detect-secrets baseline"
assert_equals "FAILED" "$(audit_secrets conf.json '        "hashed_secret": "0000000000000000000000000000000000000000",')" \
  "the same line elsewhere still fails"
assert_equals "FAILED" "$(audit_secrets sub/.secrets.baseline '        "hashed_secret": "0000000000000000000000000000000000000000",')" \
  "and so does a file of that name below the root"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
