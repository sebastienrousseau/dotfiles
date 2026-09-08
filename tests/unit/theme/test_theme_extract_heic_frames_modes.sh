#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Mode tests for scripts/theme/extract-heic-frames.sh.
#
# The script shells out to ImageMagick and libheif to split Apple's
# dynamic HEIC wallpapers into per-frame PNGs. Every case below runs it
# against a fixture wallpaper directory with `magick` and `heif-dec`
# shims, so the frame counts and the decode outcome are chosen by the
# test rather than by whatever the host has installed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

HEIC_FILE="$REPO_ROOT/scripts/theme/extract-heic-frames.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
HBIN="$TMP/heic-bin"
mkdir -p "$HBIN"
for tool in cat env printf sed grep tr wc mktemp mv rm cp dirname basename ls; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$HBIN/$tool"
done
ln -sf "$BASH" "$HBIN/bash"

# magick identify prints one line per frame; the script counts the lines.
cat >"$HBIN/magick" <<'EOF'
#!/usr/bin/env bash
# Two frames for anything named *dynamic*, one otherwise.
target="${*: -1}"
case "$target" in
  *dynamic*) printf '%s\n' "frame 0" "frame 1" ;;
  *) printf '%s\n' "frame 0" ;;
esac
exit 0
EOF
chmod +x "$HBIN/magick"

# heif-dec writes 1-indexed frame files next to the requested prefix.
cat >"$HBIN/heif-dec" <<'EOF'
#!/usr/bin/env bash
# Real usage: heif-dec -d <decoder> <input.heic> <output.png>
out="${*: -1}"
[[ -n "$out" ]] || exit 1
case "$out" in
  *broken*) exit 1 ;;
esac
printf 'png-frame-1\n' >"${out%.png}-1.png"
printf 'png-frame-2\n' >"${out%.png}-2.png"
exit 0
EOF
chmod +x "$HBIN/heif-dec"

X_OUT=""
X_RC=0
# _run_heic <wallpaper-dir> [args...]
_run_heic() {
  local dir="$1"
  shift
  X_RC=0
  X_OUT="$(
    env BASH_XTRACEFD=21 PATH="$HBIN" HOME="$TMP/heic-home" \
      DOTFILES_WALLPAPER_DIR="$dir" "$BASH" "$HEIC_FILE" "$@" </dev/null 2>&1
  )" || X_RC=$?
}

_x_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$X_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $X_RC"
  for needle in "$@"; do
    if [[ "$needle" == "NOT:"* ]]; then
      [[ "$X_OUT" == *"${needle#NOT:}"* ]] &&
        problems="${problems}\n      unexpected: ${needle#NOT:}"
    else
      [[ "$X_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
    fi
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$X_OUT" | sed 's/^/      /'
  fi
}

mkdir -p "$TMP/heic-home"

# =======================================================================
# 1. Help and unknown options.
# =======================================================================
_run_heic "$TMP/heic-home" --help
_x_expect "help_prints_the_header_comment" 0 \
  "extract per-frame PNGs from dynamic HEIC wallpapers" "Usage:"

_run_heic "$TMP/heic-home" -h
_x_expect "short_help_flag" 0 "Usage:"

_run_heic "$TMP/heic-home" --bogus
_x_expect "unknown_option_exits_1" 1 "Unknown option: --bogus"

# =======================================================================
# 2. Missing wallpaper directory, and missing decoders.
# =======================================================================
_run_heic "$TMP/heic-absent"
_x_expect "missing_wallpaper_dir_exits_1" 1 "Wallpaper dir not found:"

WALLS="$TMP/walls"
mkdir -p "$WALLS"
EMPTY_BIN="$TMP/heic-empty"
mkdir -p "$EMPTY_BIN"
for tool in cat env printf sed grep tr wc mktemp; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$EMPTY_BIN/$tool"
done
ln -sf "$BASH" "$EMPTY_BIN/bash"
X_RC=0
X_OUT="$(
  env BASH_XTRACEFD=21 PATH="$EMPTY_BIN" HOME="$TMP/heic-home" \
    DOTFILES_WALLPAPER_DIR="$WALLS" "$BASH" "$HEIC_FILE" </dev/null 2>&1
)" || X_RC=$?
_x_expect "missing_decoder_exits_1" 1 "Required: magick"

# =======================================================================
# 3. An empty wallpaper directory reports zeroes.
# =======================================================================
_run_heic "$WALLS"
_x_expect "empty_directory_reports_zeroes" 0 \
  "extracted: 0  skipped (already have PNGs): 0  single-frame: 0  failed: 0"

# =======================================================================
# 4. Extraction, skipping, single-frame and failure accounting.
# =======================================================================
printf 'heic\n' >"$WALLS/aurora-dynamic.heic"
printf 'heic\n' >"$WALLS/flat.heic"

_run_heic "$WALLS" --dry-run
_x_expect "dry_run_lists_without_extracting" 0 \
  "would extract: aurora-dynamic (frames=2)" \
  "extracted: 0  skipped (already have PNGs): 0  single-frame: 1  failed: 0"

test_start "dry_run_wrote_no_pngs"
assert_file_not_exists "$WALLS/aurora-dynamic-0.png" \
  "--dry-run must not write frame PNGs"

_run_heic "$WALLS"
_x_expect "extraction_reports_counts" 0 \
  "+ aurora-dynamic" \
  "extracted: 1  skipped (already have PNGs): 0  single-frame: 1  failed: 0"

test_start "extraction_writes_zero_indexed_frames"
_ok=1
[[ -f "$WALLS/aurora-dynamic-0.png" ]] || _ok=0
[[ -f "$WALLS/aurora-dynamic-1.png" ]] || _ok=0
grep -q 'png-frame-1' "$WALLS/aurora-dynamic-0.png" 2>/dev/null || _ok=0
grep -q 'png-frame-2' "$WALLS/aurora-dynamic-1.png" 2>/dev/null || _ok=0
if [[ "$_ok" == 1 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: frame 1 must become -0.png and frame 2 -1.png"
  ls -1 "$WALLS" | sed 's/^/      /'
fi

# A second run skips what already has PNGs; --force redoes it.
_run_heic "$WALLS"
_x_expect "second_run_skips_existing_pngs" 0 \
  "extracted: 0  skipped (already have PNGs): 1  single-frame: 1  failed: 0" \
  "NOT:+ aurora-dynamic"

_run_heic "$WALLS" --force
_x_expect "force_re_extracts" 0 \
  "+ aurora-dynamic" \
  "extracted: 1  skipped (already have PNGs): 0  single-frame: 1  failed: 0"

_run_heic "$WALLS" -f
_x_expect "force_short_flag" 0 "extracted: 1"

# -f is needed alongside -n here: the PNGs from the run above would
# otherwise be skipped before the dry-run branch is reached.
_run_heic "$WALLS" -n -f
_x_expect "dry_run_short_flag" 0 "would extract: aurora-dynamic"

# A decoder failure is collected and reported with a non-zero exit.
printf 'heic\n' >"$WALLS/broken-dynamic.heic"
_run_heic "$WALLS" --force
_x_expect "decode_failure_is_reported_and_exits_1" 1 \
  "failed: 1" "! broken-dynamic"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
