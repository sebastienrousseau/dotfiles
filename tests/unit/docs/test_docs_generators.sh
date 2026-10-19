#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Behavioural coverage for the generators that read lib/dot/data:
#   tools/docs/generate-command-reference.sh — run in a scratch tree with a
#     two-group fixture registry: write, --check in sync, --check on drift,
#     an unknown flag and a missing registry;
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
cat >"$WORK/lib/dot/data/help-specs.txt" <<'EOF'
Core|sync|Apply dotfiles|Use after clone.
Core|status|Show status|Quick look.
Tools|theme list|List themes|Pick one.
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
dot — declarative dotfiles CLI. Public commands:


[Core]
  dot sync — Apply dotfiles
  dot status — Show status

[Tools]
  dot theme list — List themes
EOF
)" "$(cat "$WORK/examples/command-reference.txt")" "grouped reference written"

test_start "reference_check_passes_when_in_sync"
ref --check
assert_equals "0" "$rc" "--check in sync exits 0"
assert_file_contains "$WORK/out" "command-reference.txt is in sync" "reports in sync"

test_start "reference_check_fails_on_drift"
printf 'Tools|theme set|Set a theme|Then reload.\n' >>"$WORK/lib/dot/data/help-specs.txt"
ref --check
assert_equals "1" "$rc" "--check on drift exits 1"
assert_file_contains "$WORK/out" "is stale" "names the stale file"

test_start "reference_rejects_an_unknown_flag"
ref --bogus
assert_equals "2" "$rc" "unknown flag exits 2"
assert_file_contains "$WORK/out" "unknown flag: --bogus" "names the flag"

test_start "reference_needs_the_registry"
rm "$WORK/lib/dot/data/help-specs.txt"
ref
assert_equals "2" "$rc" "missing registry exits 2"
assert_file_contains "$WORK/out" "registry not found" "says what is missing"

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
