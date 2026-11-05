#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# scripts/diagnostics/secret-governance.sh scans what is staged, with a real
# git. It used `git show -- ":$f"`, which reads `:$f` as a pathspec and
# prints the last commit's diff for that path: a commit that removed a
# secret failed, and a secret staged in a file whose last commit was clean
# passed. Runs a copy of the hook inside a throwaway repository, since the
# hook works on the repository it lives in.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/governance.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"
git init -q "$REPO"
mkdir -p "$REPO/scripts/diagnostics" "$REPO/plugins/secret/libexec/secret"
cp "$REPO_ROOT/scripts/diagnostics/secret-governance.sh" "$REPO/scripts/diagnostics/"
cp "$REPO_ROOT/plugins/secret/libexec/secret/secrets_provider.sh" "$REPO/plugins/secret/libexec/secret/"

# commit FILE CONTENT: commit FILE with CONTENT (hooks off, unsigned).
commit() {
  printf '%s\n' "$2" >"$REPO/$1"
  git -C "$REPO" add -A
  git -C "$REPO" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null commit -q -m "$1"
}

# govern: run the hook in the sandbox; set OUT and RC.
govern() {
  RC=0
  OUT="$(cd "$REPO" && env -u DOTFILES_SECRETS_STRICT_MODE -u DOTFILES_ALIAS_STRICT_MODE \
    bash scripts/diagnostics/secret-governance.sh 2>&1)" || RC=$?
}

# Built here so this file is not itself a plaintext secret to the hook.
KEY=api_key
SECRET="$KEY = \"a-plaintext-secret-value\""

test_start "staging_the_removal_of_a_secret_passes"
commit app.conf "$SECRET"
printf 'api_key = from_vault\n' >"$REPO/app.conf"
git -C "$REPO" add app.conf
govern
assert_equals "0" "$RC" "the staged file is clean, whatever the last commit added"

test_start "a_secret_staged_in_a_file_last_committed_clean_fails"
commit app.conf 'api_key = from_vault'
commit other.txt 'nothing here'
printf '%s\n' "$SECRET" >"$REPO/app.conf"
git -C "$REPO" add app.conf
govern
assert_equals "1" "$RC" "the staged secret is found"
assert_contains "potential plaintext secret pattern" "$OUT" "and reported"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
