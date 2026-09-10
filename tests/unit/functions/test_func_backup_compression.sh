#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The compression step of the backup function.
#
# backup compresses its archive only when the archive exceeds --max-size, and
# reports a failure only when gzip itself fails. The default threshold is
# 100M, so no test archive had ever crossed it, and gzip does not fail on its
# own — so both the success and the failure arm of that step were unrun.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/files/backup.sh"

WORK="$(mktemp -d -t backupfn.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

source "$FUNC_FILE"

mkdir -p "$WORK/stubs" "$WORK/src" "$WORK/dest"
dot_fixture_basebin "$WORK/base" tar gzip
printf 'payload\n' >"$WORK/src/file.txt"

BK_OUT=""
BK_RC=0
# bk_run <bin-dir> [args...] — run backup with the given PATH and a backup
# directory inside the sandbox.
bk_run() {
  local bindir="$1"
  shift
  BK_RC=0
  BK_OUT="$(
    cd "$WORK/src" &&
      PATH="$bindir:$WORK/base" BACKUP_DIR="$WORK/dest" backup "$@" 2>&1
  )" || BK_RC=$?
}

# ── 1. An archive over the threshold is compressed ─────────────────────────
test_start "backup_compresses_an_archive_over_the_threshold"
rm -f "$WORK/dest"/*
bk_run "$WORK/base" --max-size 1 file.txt
assert_equals "0" "$BK_RC" "a compressed backup should succeed"
assert_contains "Compressed to" "$BK_OUT" "the compression should be reported"

# ── 2. A gzip that fails is reported, not swallowed ────────────────────────
test_start "backup_reports_a_failed_compression"
rm -f "$WORK/dest"/*
printf '#!/bin/sh\nexit 1\n' >"$WORK/stubs/gzip"
chmod +x "$WORK/stubs/gzip"
bk_run "$WORK/stubs" --max-size 1 file.txt
assert_equals "1" "$BK_RC" "a failed compression should return 1"
assert_contains "Failed to compress the backup" "$BK_OUT" \
  "the failure should say what went wrong"

# ── 3. Below the threshold nothing is compressed ───────────────────────────
test_start "backup_leaves_a_small_archive_uncompressed"
rm -f "$WORK/dest"/*
bk_run "$WORK/base" --max-size 100M file.txt
assert_equals "0" "$BK_RC" "an uncompressed backup should succeed"
assert_contains "No compression required" "$BK_OUT" \
  "the decision not to compress should be reported"

print_summary
