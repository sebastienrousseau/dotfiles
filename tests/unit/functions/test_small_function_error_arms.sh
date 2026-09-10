#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The "it went wrong" arms of four small file-management functions.
#
# rd, ren, sentencecase and hiddenfiles each carry a failure branch that
# nothing had ever taken, because taking it needs the filesystem or the
# platform to misbehave on purpose: a directory that stats but cannot be
# entered, a rename into a directory that refuses new entries, a filename
# that is already in the target form, and a kernel that is not Darwin.
#
# Every case works inside a temporary directory this suite creates and
# restores the permissions it changed, so nothing is left unwritable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

FN_DIR="$REPO_ROOT/defaults/.chezmoitemplates/functions"

WORK="$(mktemp -d -t smallfn.XXXXXX)"
cov_setup_sandbox
# chmod back before removing: a 555 directory cannot have its entries deleted.
trap 'chmod -R u+rwx "$WORK" 2>/dev/null || true; rm -rf "$WORK"; cov_teardown_sandbox' EXIT

source "$FN_DIR/files/rd.sh"
source "$FN_DIR/files/ren.sh"
source "$FN_DIR/text/sentencecase.sh"
source "$FN_DIR/files/hiddenfiles.sh"

mkdir -p "$WORK/stubs"
dot_fixture_basebin "$WORK/base"

# ── 1. rd: a directory that stats but cannot be entered ────────────────────
test_start "rd_reports_an_unresolvable_directory"
mkdir -p "$WORK/sealed"
chmod 000 "$WORK/sealed"
out="$(rd "$WORK/sealed" 2>&1)"
rc=$?
chmod 755 "$WORK/sealed"
assert_equals "1" "$rc" "a directory that cannot be entered should return 1"
assert_contains "Cannot resolve path" "$out" \
  "the failure should say the path could not be resolved"

# ── 2. sentencecase ────────────────────────────────────────────────────────
test_start "sentencecase_skips_a_name_already_in_form"
mkdir -p "$WORK/sc"
: >"$WORK/sc/Already.txt"
out="$(sentencecase "$WORK/sc/Already.txt" 2>&1)"
assert_contains "already in sentence case" "$out" \
  "a filename already in sentence case should be left alone"
assert_file_exists "$WORK/sc/Already.txt" "and must not be renamed"

test_start "sentencecase_reports_a_failed_rename"
mkdir -p "$WORK/sc-ro"
: >"$WORK/sc-ro/NEEDS.txt"
chmod 555 "$WORK/sc-ro"
out="$(sentencecase "$WORK/sc-ro/NEEDS.txt" 2>&1)"
chmod 755 "$WORK/sc-ro"
assert_contains "Failed to rename" "$out" \
  "a rename the filesystem refuses should be reported, not swallowed"

# ── 3. ren: a rename the filesystem refuses ────────────────────────────────
test_start "ren_reports_a_failed_rename"
mkdir -p "$WORK/ren-ro"
: >"$WORK/ren-ro/note.txt"
chmod 555 "$WORK/ren-ro"
out="$(cd "$WORK/ren-ro" && printf 'y\n' | ren txt md 2>&1)"
chmod 755 "$WORK/ren-ro"
assert_contains "Failed to rename" "$out" \
  "a rename the filesystem refuses should be reported, not swallowed"

# ── 4. hiddenfiles is macOS-only ───────────────────────────────────────────
test_start "hiddenfiles_refuses_a_non_darwin_host"
printf '#!/bin/sh\nprintf "Linux\\n"\n' >"$WORK/stubs/uname"
chmod +x "$WORK/stubs/uname"
out="$(PATH="$WORK/stubs:$WORK/base" hiddenfiles show 2>&1)"
rc=$?
assert_equals "1" "$rc" "a non-Darwin host should return 1"
assert_contains "macOS only" "$out" "the refusal should say why"

print_summary
