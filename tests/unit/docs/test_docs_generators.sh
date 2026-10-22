#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Behavioural coverage for the generators that read lib/dot/data:
#   tools/docs/generate-command-reference.sh — run in a scratch tree with a
#     two-domain fixture command table: write (planned commands left out),
#     --check in sync, --check on drift, an unknown flag and a missing table;
#   tools/docs/generate-command-index.sh and tools/docs/generate-manpage.sh —
#     --check against the committed outputs, so any change to what they
#     generate shows up as drift.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-docs-gen.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

REF_GEN="$WORK/tools/docs/generate-command-reference.sh"
mkdir -p "$WORK/tools/docs" "$WORK/lib/dot/data" "$WORK/examples"
cp "$REPO_ROOT/tools/docs/generate-command-reference.sh" "$REF_GEN"
cat >"$WORK/lib/dot/data/commands.txt" <<'EOF'
# a comment line is skipped
dom|config|status||apply, diff and sync the dotfiles
dom|theme|show|theme|one palette for every app
cmd|config sync|sync|write|Pull the source, then apply
cmd|config status|status|read|Pending changes
cmd|config export||read|Export the setup
cmd|theme list|theme list|read|Available themes
alias|sync|shortcut|config sync|
alias|search|deprecated|help|0.2.538
EOF

# ref <args...> — run the reference generator; stdout+stderr to $WORK/out.
ref() {
  rc=0
  bash "$REF_GEN" "$@" >"$WORK/out" 2>&1 || rc=$?
}

test_start "reference_writes_one_heading_per_group"
ref
assert_equals "0" "$rc" "write exits 0"
assert_equals "$(
  cat <<'EOF'
dot — one command for this machine. Built commands, by domain:

[config] apply, diff and sync the dotfiles
  dot config sync — Pull the source, then apply
  dot config status — Pending changes

[theme] one palette for every app
  dot theme list — Available themes

[shortcuts]
  dot sync — short for dot config sync
EOF
)" "$(cat "$WORK/examples/command-reference.txt")" "built commands by domain, then the shortcuts"

test_start "reference_check_passes_when_in_sync"
ref --check
assert_equals "0" "$rc" "--check in sync exits 0"
assert_file_contains "$WORK/out" "command-reference.txt is in sync" "reports in sync"

test_start "reference_check_fails_on_drift"
printf 'cmd|theme set|theme set|write|Switch theme\n' >>"$WORK/lib/dot/data/commands.txt"
ref --check
assert_equals "1" "$rc" "--check on drift exits 1"
assert_file_contains "$WORK/out" "is stale" "names the stale file"

test_start "reference_rejects_an_unknown_flag"
ref --bogus
assert_equals "2" "$rc" "unknown flag exits 2"
assert_file_contains "$WORK/out" "unknown flag: --bogus" "names the flag"

test_start "reference_needs_the_command_table"
rm "$WORK/lib/dot/data/commands.txt"
ref
assert_equals "2" "$rc" "missing table exits 2"
assert_file_contains "$WORK/out" "command table not found" "says what is missing"

test_start "command_index_matches_the_registry"
rc=0
bash "$REPO_ROOT/tools/docs/generate-command-index.sh" --check >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "committed command index is what the generator writes"

test_start "manpage_matches_the_registry"
rc=0
bash "$REPO_ROOT/tools/docs/generate-manpage.sh" --check >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "committed man page is what the generator writes"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
