#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# version-sync's rewrite rules must move the current-version references in
# install.sh and leave its historical ones alone. Sources
# scripts/version-sync.sh (main does not run when sourced) in a subshell
# and runs its real _vs_rewrite on a copy of install.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$REPO_ROOT/install.sh" "$WORK/install.sh"
(
  source "$REPO_ROOT/scripts/version-sync.sh"
  _vs_rewrite install.sh "$WORK/install.sh" 9.9.9
)
REWRITTEN="$(cat "$WORK/install.sh")"

test_start "version_sync_moves_the_installer_default"
assert_contains 'local version="v9.9.9"' "$REWRITTEN" "the default version follows the release"

test_start "version_sync_keeps_the_v0_2_503_migration_label"
assert_contains "Auto-migration for the 0.2.503 reorg" "$REWRITTEN" "the comment keeps its version"
assert_contains "Running the 0.2.503 layout migration" "$REWRITTEN" "the message keeps its version"
assert_equals "0" "$(printf '%s\n' "$REWRITTEN" | grep -iE 'migration|reorg' | grep -c '9\.9\.9' || true)" "no migration line is stamped with the new version"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
