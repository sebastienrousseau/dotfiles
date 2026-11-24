#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# install/migrate/link-standards.sh: each of ~/Code's standard files
# becomes a symlink into the standards clone, unless it was edited in
# place; the script never fails an apply.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LINK="$REPO_ROOT/install/migrate/link-standards.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
N=0
FILES=(AGENTS.md GEMINI.md PR-TEMPLATE.md README-TEMPLATE.md REPO-STANDARD.md)

# fresh: a clone with the five files and an empty ~/Code.
fresh() {
  N=$((N + 1))
  CLONE="$WORK/c$N/standards"
  CODE="$WORK/c$N/Code"
  mkdir -p "$CLONE" "$CODE"
  for f in "${FILES[@]}"; do printf 'canonical %s\n' "$f" >"$CLONE/$f"; done
}

# run [CLONE]: set OUT (stdout and stderr) and RC.
run() {
  RC=0
  OUT="$(bash "$LINK" "${1:-$CLONE}" "$CODE" 2>&1)" || RC=$?
}

# link_of FILE: the target of ~/Code/FILE when it is a symlink, else "file".
link_of() {
  if [[ -L "$CODE/$1" ]]; then readlink "$CODE/$1"; else echo file; fi
}

test_start "missing_files_are_linked"
fresh
run
assert_equals "0" "$RC" "exits 0"
for f in "${FILES[@]}"; do
  assert_equals "$CLONE/$f" "$(link_of "$f")" "$f links into the clone"
done
assert_contains "linked ${CODE}/AGENTS.md" "$OUT" "says what it linked"

test_start "an_identical_copy_becomes_a_link"
fresh
cp "$CLONE/AGENTS.md" "$CODE/AGENTS.md"
run
assert_equals "0" "$RC" "exits 0"
assert_equals "$CLONE/AGENTS.md" "$(link_of AGENTS.md)" "the copy is replaced by a link"

test_start "an_edited_copy_is_kept"
fresh
printf 'edited in place\n' >"$CODE/AGENTS.md"
run
assert_equals "0" "$RC" "exits 0, never failing the apply"
assert_equals "file" "$(link_of AGENTS.md)" "the edited file stays a file"
assert_equals "edited in place" "$(cat "$CODE/AGENTS.md")" "its content is untouched"
assert_contains "kept ${CODE}/AGENTS.md" "$OUT" "names the kept file"
assert_contains "standards-sync --pull" "$OUT" "says how to adopt the edit"
assert_equals "$CLONE/GEMINI.md" "$(link_of GEMINI.md)" "the other files are still linked"

test_start "an_existing_link_is_left_alone"
fresh
run
run
assert_equals "0" "$RC" "exits 0"
assert_equals "" "$OUT" "a second run has nothing to say"
assert_equals "$CLONE/AGENTS.md" "$(link_of AGENTS.md)" "the link is unchanged"

test_start "a_link_elsewhere_is_repointed"
fresh
printf 'other\n' >"$WORK/other.md"
ln -s "$WORK/other.md" "$CODE/AGENTS.md"
run
assert_equals "0" "$RC" "exits 0"
assert_equals "$CLONE/AGENTS.md" "$(link_of AGENTS.md)" "the link now points into the clone"
assert_equals "other" "$(cat "$WORK/other.md")" "the old link's target is untouched"

test_start "a_directory_is_kept"
fresh
mkdir "$CODE/AGENTS.md"
run
assert_equals "0" "$RC" "exits 0"
if [[ -d "$CODE/AGENTS.md" && ! -L "$CODE/AGENTS.md" ]]; then kept_dir=yes; else kept_dir=no; fi
assert_equals "yes" "$kept_dir" "the directory stays"
assert_contains "kept ${CODE}/AGENTS.md" "$OUT" "names it"

test_start "no_clone_is_a_no_op"
fresh
run "$WORK/c$N/absent"
assert_equals "0" "$RC" "exits 0"
assert_equals "" "$OUT" "says nothing"
assert_equals "" "$(ls -A "$CODE")" "creates nothing"

test_start "a_file_missing_from_the_clone_is_skipped"
fresh
rm "$CLONE/GEMINI.md"
run
assert_equals "0" "$RC" "exits 0"
if [[ -e "$CODE/GEMINI.md" || -L "$CODE/GEMINI.md" ]]; then made=yes; else made=no; fi
assert_equals "no" "$made" "no dangling link is made"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
