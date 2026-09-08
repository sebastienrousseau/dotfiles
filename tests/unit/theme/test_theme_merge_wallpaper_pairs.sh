#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for scripts/theme/merge-wallpaper.sh: dependency
# checks, --help, --dry-run, single-family and sweep modes, and the failure
# path when the encoder rejects a pair.
#
# `heif-enc`, `magick` and `exiftool` are recording stubs in the sandbox and
# the wallpaper directory is a throwaway under $DOTFILES_COV_TMPDIR, so no
# real image is ever read, written or deleted.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

MERGE="$REPO_ROOT/scripts/theme/merge-wallpaper.sh"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"
WALLS="$DOTFILES_COV_TMPDIR/wallpapers"
export MERGE_CALLS="$DOTFILES_COV_TMPDIR/calls.txt"
mkdir -p "$WALLS"

cat >"$BIN/magick" <<STUB
#!$REAL_BASH
printf 'magick %s\\n' "\$*" >>"\$MERGE_CALLS"
# Last argument is the output path; produce a plausible JPEG for heif-enc.
printf 'jpeg-bytes\\n' >"\${!#}"
exit 0
STUB
cat >"$BIN/heif-enc" <<STUB
#!$REAL_BASH
printf 'heif-enc %s\\n' "\$*" >>"\$MERGE_CALLS"
[[ "\${HEIF_ENC_RC:-0}" -ne 0 ]] && exit "\$HEIF_ENC_RC"
out=""
while ((\$#)); do
  [[ "\$1" == "-o" ]] && out="\$2"
  shift
done
printf 'heic-bytes\\n' >"\$out"
exit 0
STUB
cat >"$BIN/exiftool" <<STUB
#!$REAL_BASH
printf 'exiftool %s\\n' "\$*" >>"\$MERGE_CALLS"
exit 0
STUB
chmod +x "$BIN/magick" "$BIN/heif-enc" "$BIN/exiftool"

merge() {
  : >"$MERGE_CALLS"
  # stderr is replayed rather than merged so the child's xtrace still reaches
  # the coverage trace.
  DOTFILES_WALLPAPER_DIR="$WALLS" bash "$MERGE" "$@" >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  assert_file_contains "$MERGED" "$1" "${2:-output contains $1}"
}
called() { assert_file_contains "$MERGE_CALLS" "$1" "invoked $1"; }

pair() {
  printf 'dark-pixels\n' >"$WALLS/$1-dark.${2:-heic}"
  printf 'light-pixels\n' >"$WALLS/$1-light.${2:-heic}"
}

test_start "script_exists_and_parses"
assert_file_exists "$MERGE" "merge-wallpaper.sh must exist"
assert_true "bash -n '$MERGE'" "valid bash syntax"

test_start "help_documents_the_merge"
merge --help
assert_equals 0 "$RC" "rc"
out_has "Usage: merge-wallpaper.sh" "usage"
out_has "switches appearance automatically on macOS" "explanation"

test_start "the_encoder_is_required"
NOENC="$DOTFILES_COV_TMPDIR/noenc"
mkdir -p "$NOENC"
ln -sf "$REAL_BASH" "$NOENC/bash"
for c in printf echo cat basename mktemp rm mv; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOENC/$c"
done
PATH="$NOENC" merge
assert_equals 1 "$RC" "rc"
out_has "heif-enc required" "error names libheif"

test_start "imagemagick_is_required"
ln -sf "$BIN/heif-enc" "$NOENC/heif-enc"
PATH="$NOENC" merge
assert_equals 1 "$RC" "rc"
out_has "ImageMagick (magick) required" "error"

test_start "dry_run_reports_the_pairs_without_touching_them"
pair macos-tahoe
merge --dry-run
assert_equals 0 "$RC" "rc"
out_has "would merge" "preview"
out_has "macos-tahoe" "family named"
out_has "Done: 1 merged, 0 failed" "summary"
assert_file_exists "$WALLS/macos-tahoe-dark.heic" "inputs untouched"
assert_file_not_exists "$WALLS/macos-tahoe.heic" "no output written"
assert_true "! [[ -s '$MERGE_CALLS' ]]" "no encoder invoked"

test_start "a_pair_is_merged_into_one_dynamic_heic"
merge
assert_equals 0 "$RC" "rc"
out_has "merged →" "confirmation"
out_has "Done: 1 merged, 0 failed" "summary"
out_has "dot theme rebuild --force" "follow-up hint"
assert_file_exists "$WALLS/macos-tahoe.heic" "output written"
assert_file_not_exists "$WALLS/macos-tahoe-dark.heic" "dark input consumed"
assert_file_not_exists "$WALLS/macos-tahoe-light.heic" "light input consumed"
called "magick"
called "heif-enc -q 90"
called "exiftool -overwrite_original"

test_start "a_named_family_is_merged_on_its_own"
pair alpha
pair beta
merge alpha
assert_equals 0 "$RC" "rc"
out_has "alpha — merged" "named family merged"
assert_file_exists "$WALLS/alpha.heic" "output written"
assert_file_exists "$WALLS/beta-dark.heic" "other family left alone"

test_start "jpeg_and_png_pairs_are_found_too"
rm -f "$WALLS"/*
pair gamma jpg
pair delta png
merge
assert_equals 0 "$RC" "rc"
out_has "Done: 2 merged, 0 failed" "both families merged"
assert_file_exists "$WALLS/gamma.heic" "jpg pair merged"
assert_file_exists "$WALLS/delta.heic" "png pair merged"

test_start "an_unpaired_family_is_reported_as_a_failure"
rm -f "$WALLS"/*
printf 'dark-only\n' >"$WALLS/lonely-dark.heic"
merge
assert_equals 0 "$RC" "rc"
out_has "missing dark or light variant" "reason"
out_has "Done: 0 merged, 1 failed" "summary"

test_start "a_named_family_with_no_files_fails"
merge nosuchfamily
assert_equals 1 "$RC" "rc"
out_has "nosuchfamily — missing dark or light variant" "reason"

test_start "an_encoder_failure_is_reported_and_keeps_the_inputs"
rm -f "$WALLS"/*
pair epsilon
HEIF_ENC_RC=1 merge
assert_equals 0 "$RC" "rc"
out_has "heif-enc failed" "reason"
out_has "Done: 0 merged, 1 failed" "summary"
assert_file_exists "$WALLS/epsilon-dark.heic" "inputs kept"
assert_file_not_exists "$WALLS/epsilon.heic" "no output"

test_start "an_empty_wallpaper_directory_merges_nothing"
rm -f "$WALLS"/*
merge
assert_equals 0 "$RC" "rc"
out_has "Done: 0 merged, 0 failed" "summary"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
