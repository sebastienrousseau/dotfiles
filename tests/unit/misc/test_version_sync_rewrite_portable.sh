#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# version-sync's bare vX.Y.Z rule must give the same result under BSD sed
# (macOS) as under GNU sed. The expected text below is what GNU sed produced
# with the old `\bvX.Y.Z\b` rule; BSD sed has no \b and used to leave every
# bare version stale. Sources scripts/version-sync.sh (main does not run
# when sourced) and runs its real _vs_rewrite.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat >"$WORK/notes.md" <<'TXT'
v0.2.529 at line start
on v0.2.504/v0.2.505) adjacent
tag v0.2.529abc stays
xv0.2.529 stays
v0.2.529_x stays
v0.2.529.1 trailing dot
MILESTONE v0.2.529 stays
end v0.2.529
TXT
(
  source "$REPO_ROOT/scripts/version-sync.sh"
  _vs_rewrite docs/notes.md "$WORK/notes.md" 9.9.9
)
OUT="$(cat "$WORK/notes.md")"

test_start "version_sync_rewrites_bare_versions_at_word_boundaries"
assert_equals "v9.9.9 at line start" "$(sed -n 1p <<<"$OUT")" "a version at the start of a line"
assert_equals "end v9.9.9" "$(sed -n 8p <<<"$OUT")" "a version at the end of a line"
assert_equals "v9.9.9.1 trailing dot" "$(sed -n 6p <<<"$OUT")" "a dot after the patch number is a boundary"

test_start "version_sync_rewrites_adjacent_versions"
assert_equals "on v9.9.9/v9.9.9) adjacent" "$(sed -n 2p <<<"$OUT")" "both halves of v1/v2 move"

test_start "version_sync_leaves_versions_inside_words"
assert_equals "tag v0.2.529abc stays" "$(sed -n 3p <<<"$OUT")" "followed by a letter"
assert_equals "xv0.2.529 stays" "$(sed -n 4p <<<"$OUT")" "preceded by a letter"
assert_equals "v0.2.529_x stays" "$(sed -n 5p <<<"$OUT")" "followed by an underscore"

test_start "version_sync_skips_milestone_lines"
assert_equals "MILESTONE v0.2.529 stays" "$(sed -n 7p <<<"$OUT")" "MILESTONE lines are historical"

test_start "version_sync_leaves_no_marker_behind"
assert_equals "0" "$(grep -c 'VSYNC' <<<"$OUT" || true)" "the internal marker never reaches a file"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
