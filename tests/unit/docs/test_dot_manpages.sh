#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The man pages (ADR-020, N0.4, N12): tools/docs/gen_manpages.py writes
# dot(1) and one dot-<domain>(1) per domain from the command table, and the
# committed pages are what it writes. Every domain has a page, every command
# appears on its domain's page, and a stale or orphaned page fails --check.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GEN="$REPO_ROOT/tools/docs/gen_manpages.py"
WRAP="$REPO_ROOT/tools/docs/generate-manpage.sh"
MAN="$REPO_ROOT/share/man/man1"
TABLE="$REPO_ROOT/lib/dot/data/commands.txt"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-man.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

test_start "committed_pages_are_current"
rc=0
bash "$WRAP" --check >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "tools/docs/generate-manpage.sh --check: $(cat "$WORK/out")"

test_start "one_page_per_domain_with_every_command"
missing=""
while IFS='|' read -r rec key _; do
  case "$rec" in
    dom) [[ -f "$MAN/dot-$key.1" ]] || missing="$missing dot-$key.1" ;;
    cmd)
      d="${key%% *}"
      grep -qF ".B dot ${key//-/\\-}" "$MAN/dot-$d.1" 2>/dev/null || missing="$missing $key"
      ;;
  esac
done <"$TABLE"
assert_equals "" "$missing" "each domain has a page listing each of its commands"
assert_file_contains "$MAN/dot-doctor.1" '.B \-\-runs, \-r \fIcount\fR' "a command's flags, with the value they take"
assert_file_contains "$MAN/dot.1" ".BR dot\\-system (1)" "dot(1) points at each domain's page"
assert_file_contains "$MAN/dot.1" "Unknown command, removed name or missing plugin" "and lists the exit codes"

test_start "output_writes_dot1_and_the_domain_pages"
rc=0
bash "$WRAP" --output "$WORK/build/man1/dot.1" >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "--output writes"
want_pages=("$MAN"/*.1) got_pages=("$WORK/build/man1"/*.1)
assert_equals "${#want_pages[@]}" "${#got_pages[@]}" "every page beside FILE"
rc=0
bash "$WRAP" --output >/dev/null 2>&1 || rc=$?
assert_equals "2" "$rc" "--output needs a path"
rc=0
bash "$WRAP" --bogus >/dev/null 2>&1 || rc=$?
assert_equals "2" "$rc" "an unknown flag exits 2"

rc=0
bash "$WRAP" --output "$WORK/other/page.1" >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "--output to another name writes"
assert_file_contains "$WORK/other/page.1" ".TH DOT 1" "dot(1) under that name"

test_start "command_index_generator"
INDEX="$REPO_ROOT/tools/docs/generate-command-index.sh"
rc=0
bash "$INDEX" --check >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "tools/docs/generate-command-index.sh --check passes on the repository"
assert_file_contains "$WORK/out" "command-index.md is in sync" "and checks rather than writes"
rc=0
bash "$INDEX" --bogus >/dev/null 2>&1 || rc=$?
assert_equals "2" "$rc" "an unknown flag exits 2"

test_start "stale_and_orphaned_pages_fail_the_check"
cp -R "$MAN" "$WORK/man"
printf '.\\" edited\n' >>"$WORK/man/dot-system.1"
touch "$WORK/man/dot-gone.1"
rc=0
python3 "$GEN" --root "$REPO_ROOT" --outdir "$WORK/man" --check 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "--check fails"
assert_file_contains "$WORK/err" "dot-system.1 is stale" "names the stale page"
assert_file_contains "$WORK/err" "dot-gone.1 is not generated" "and the orphan"

test_start "pages_pass_mandoc_lint"
if command -v mandoc >/dev/null 2>&1; then
  : >"$WORK/lint"
  for f in "$MAN"/dot*.1; do mandoc -T lint -W warning "$f" >>"$WORK/lint" 2>&1 || true; done
  assert_equals "" "$(cat "$WORK/lint")" "no mandoc warnings"
else
  assert_true "true" "mandoc not installed; skipped"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
