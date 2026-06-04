#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/extract-heic-frames.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "extract-heic-frames.sh should exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "script_executable"
if [[ -x "$SCRIPT_FILE" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing +x"
fi

# Documented choices that downstream users depend on. heif-dec's
# `-d ffmpeg` flag is non-obvious and was the key debugging insight
# (libde265 fails where ffmpeg succeeds on Apple dynamic HEIC); pin
# the test so a future refactor can't silently drop it.
test_start "uses_heif_dec_ffmpeg"
assert_file_contains "$SCRIPT_FILE" "heif-dec -d ffmpeg" \
  "must use heif-dec -d ffmpeg (libde265 default decoder fails)"

test_start "honours_dotfiles_wallpaper_dir"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_WALLPAPER_DIR" \
  "must honour DOTFILES_WALLPAPER_DIR override"

test_start "writes_zero_indexed_frames"
assert_file_contains "$SCRIPT_FILE" '${name}-0.png' \
  "must write the 0-indexed light frame next to the HEIC"
assert_file_contains "$SCRIPT_FILE" '${name}-1.png' \
  "must write the 1-indexed dark frame next to the HEIC"

test_start "supports_force_flag"
assert_file_contains "$SCRIPT_FILE" -- "--force" \
  "must accept --force to re-extract existing PNGs"

test_start "supports_dry_run"
assert_file_contains "$SCRIPT_FILE" -- "--dry-run" \
  "must support --dry-run for inspection"

# Drive real line coverage of the script under test.
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
