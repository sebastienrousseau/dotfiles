#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/wallpaper-sync.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "script should exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# macos_appearance_frame must return non-HEIC wallpapers unchanged so static
# wallpapers are never rewritten; only multi-frame dynamic HEICs get resolved
# to a per-mode frame (that path is macOS + magick specific).
test_start "appearance_frame_passthrough_non_heic"
_af_out="$(
  eval "$(sed -n '/^macos_appearance_frame()/,/^}/p' "$SCRIPT_FILE")"
  WALLPAPER_DIR=/tmp
  macos_appearance_frame "/a/b/pic.png" "light"
)"
assert_equals "$_af_out" "/a/b/pic.png" "non-HEIC wallpaper returned unchanged"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
