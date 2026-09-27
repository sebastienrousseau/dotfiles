#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
# Stub magick/heif-dec: a .heic file's content is its frame count; heif-dec
# writes <out>-1.png .. <out>-N.png like the real `-d ffmpeg` decoder, or
# fails when the file says "broken".
HX="$DOTFILES_COV_TMPDIR/heic"
mkdir -p "$HX/bin" "$HX/walls"
cat >"$HX/bin/magick" <<'STUB'
#!/bin/sh
# magick identify <file>: one line per frame
n=$(head -c 1 "$2")
i=0; while [ "$i" -lt "$n" ]; do echo "$2[$i] HEIC"; i=$((i + 1)); done
STUB
cat >"$HX/bin/heif-dec" <<'STUB'
#!/bin/sh
# heif-dec -d ffmpeg <in> <out.png>
grep -q broken "$3" && exit 1
n=$(head -c 1 "$3"); base="${4%.png}"
i=1; while [ "$i" -le "$n" ]; do echo "frame $i of $3" >"$base-$i.png"; i=$((i + 1)); done
STUB
chmod +x "$HX/bin/magick" "$HX/bin/heif-dec"

# heic [args...]: run the script on $HX/walls; sets rc and out.
heic() {
  out=$(DOTFILES_WALLPAPER_DIR="$HX/walls" PATH="$HX/bin:$PATH" bash "$SCRIPT_FILE" "$@" 2>&1)
  rc=$?
}
printf '2' >"$HX/walls/dune.heic"
printf '1' >"$HX/walls/flat.heic"

test_start "dry_run_writes_nothing"
heic --dry-run
assert_equals "0:0" "$rc:$(find "$HX/walls" -name '*.png' | wc -l | tr -d ' ')" "--dry-run only reports"

test_start "extracts_two_frames_zero_indexed"
heic
assert_equals "frame 1 of dune.heic|frame 2 of dune.heic" "$(cat "$HX/walls/dune-0.png")|$(cat "$HX/walls/dune-1.png")" "decoder frames 1,2 land as -0/-1"

test_start "single_frame_is_skipped"
assert_contains "extracted: 1  skipped (already have PNGs): 0  single-frame: 1  failed: 0" "$out" "summary counts one extraction and one single-frame file"

test_start "existing_pngs_are_kept"
heic
assert_contains "extracted: 0  skipped (already have PNGs): 1" "$out" "a rerun skips files that already have both PNGs"

test_start "force_reextracts"
heic --force
assert_contains "extracted: 1" "$out" "--force extracts again"

test_start "decoder_failure_fails_the_run"
printf '2 broken' >"$HX/walls/bad.heic"
heic
assert_equals "1" "$rc" "a failed decode exits 1 and is listed"

test_start "missing_wallpaper_dir_fails"
out=$(DOTFILES_WALLPAPER_DIR="$HX/nope" PATH="$HX/bin:$PATH" bash "$SCRIPT_FILE" 2>&1) && rc=0 || rc=$?
assert_equals "1" "$rc" "an absent wallpaper dir is an error"

cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
