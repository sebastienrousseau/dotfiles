#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# scripts/git-hooks/pre-commit runs the secret governance and the audit of
# the checkout being committed. It found them beside its own file, which is
# installed in the main checkout's .git/hooks, so a commit in a linked
# worktree ran the main checkout's copies: an older tree's checks on a
# newer tree's commit. Commits in a throwaway repository and its worktree,
# with stub checks that say which checkout they belong to.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hook-wt.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
MAIN="$WORK/main"
LINKED="$WORK/linked"
LOG="$WORK/ran.log"

# stub_checks DIR NAME: governance and audit stubs that log NAME.
stub_checks() {
  mkdir -p "$1/scripts/diagnostics" "$1/scripts/git-hooks"
  printf '#!/usr/bin/env bash\necho "%s governance" >>"%s"\n' "$2" "$LOG" >"$1/scripts/diagnostics/secret-governance.sh"
  printf '#!/usr/bin/env bash\necho "%s audit" >>"%s"\n' "$2" "$LOG" >"$1/scripts/git-hooks/pre-commit-audit.sh"
  chmod +x "$1/scripts/diagnostics/secret-governance.sh" "$1/scripts/git-hooks/pre-commit-audit.sh"
}

g() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }

git init -q "$MAIN"
stub_checks "$MAIN" main
g -C "$MAIN" add -A
g -C "$MAIN" -c core.hooksPath=/dev/null commit -q -m init
g -C "$MAIN" worktree add -q -b side "$LINKED"
stub_checks "$LINKED" linked
install -m 0755 "$REPO_ROOT/scripts/git-hooks/pre-commit" "$MAIN/.git/hooks/pre-commit"

# commit_in DIR: commit a new file in DIR through the installed hook.
commit_in() {
  : >"$LOG"
  echo x >"$(mktemp "$1/f-XXXXXX")"
  g -C "$1" add -A
  g -C "$1" -c core.hooksPath="$MAIN/.git/hooks" commit -q -m change >/dev/null 2>&1
}

test_start "a_commit_in_the_main_checkout_runs_its_checks"
commit_in "$MAIN"
assert_equals "main governance|main audit" "$(tr '\n' '|' <"$LOG" | sed 's/|$//')" "the main checkout's checks"

test_start "a_commit_in_a_linked_worktree_runs_the_worktree_checks"
commit_in "$LINKED"
assert_equals "linked governance|linked audit" "$(tr '\n' '|' <"$LOG" | sed 's/|$//')" \
  "the worktree's own checks, not the main checkout's"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
