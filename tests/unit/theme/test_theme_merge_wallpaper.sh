#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/merge-wallpaper.sh"

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

# heif-enc builds the multi-image HEIC from both variants, light first (the
# primary image); the merged file replaces the pair. Without heif-enc the
# script stops before touching anything.
test_start "uses_heif_enc"
mw_bin="$DOTFILES_COV_TMPDIR/mw-bin"
mw_walls="$DOTFILES_COV_TMPDIR/mw-walls"
mkdir -p "$mw_bin" "$mw_walls"
cat >"$mw_bin/magick" <<'STUB'
#!/usr/bin/env bash
cp "$1" "${*: -1}"
STUB
cat >"$mw_bin/heif-enc" <<'STUB'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q) shift ;;
    -o) out="$2"; shift ;;
    *) inputs+=("$1") ;;
  esac
  shift
done
cat "${inputs[@]}" >"$out"
STUB
chmod +x "$mw_bin/magick" "$mw_bin/heif-enc"
echo light >"$mw_walls/sea-light.heic"
echo dark >"$mw_walls/sea-dark.heic"
mw_rc=0
DOTFILES_WALLPAPER_DIR="$mw_walls" PATH="$mw_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" \
  bash "$SCRIPT_FILE" sea >/dev/null 2>&1 || mw_rc=$?
assert_equals "0" "$mw_rc" "the merge exits 0"
assert_equals "light dark" "$(tr '\n' ' ' <"$mw_walls/sea.heic" 2>&1 | sed 's/ $//')" "light is image 0, dark image 1"
assert_equals "sea.heic" "$(ls "$mw_walls")" "the merged file replaces the pair"
rm "$mw_bin/heif-enc"
echo light >"$mw_walls/sun-light.heic"
mw_rc=0
mw_out="$(DOTFILES_WALLPAPER_DIR="$mw_walls" PATH="$mw_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" \
  bash "$SCRIPT_FILE" sun 2>&1)" || mw_rc=$?
assert_equals "1 Error: heif-enc required (brew install libheif)" "$mw_rc $mw_out" "no heif-enc, no merge"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
