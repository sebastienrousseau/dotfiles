#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/wallpaper-rotate.sh"

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

# macOS: the path reaches AppleScript as an argument, never as script text.
# Runs anywhere: uname says Darwin and osascript is a recording stub.
test_start "rotate_macos_passes_the_path_to_applescript_as_data"
ROT="$(mktemp -d)"
mkdir -p "$ROT/bin" "$ROT/wp"
printf '#!/usr/bin/env bash\necho Darwin\n' >"$ROT/bin/uname"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >"%s/argv"\ncat >"%s/script"\n' "$ROT" "$ROT" >"$ROT/bin/osascript"
chmod +x "$ROT/bin/uname" "$ROT/bin/osascript"
: >"$ROT/wp/a\"b&c-dark.jpg"
rot_out="$(PATH="$ROT/bin:$PATH" DOTFILES_WALLPAPER_DIR="$ROT/wp" bash "$SCRIPT_FILE" --once --dark </dev/null 2>&1)"
assert_contains 'Wallpaper applied (dark): a"b&c-dark.jpg' "$rot_out" "the rotation completes"
assert_equals "-"$'\n'"$ROT/wp/a\"b&c-dark.jpg" "$(cat "$ROT/argv" 2>/dev/null)" "script from stdin, the path as the one argument"
assert_contains "on run argv" "$(cat "$ROT/script" 2>/dev/null)" "the script reads its argument"
assert_contains "set picture of every desktop to theFile" "$(cat "$ROT/script" 2>/dev/null)" "and sets every desktop"
assert_equals "no" "$(grep -qF 'a"b&c' "$ROT/script" 2>/dev/null && echo yes || echo no)" "the file name never appears in the script text"
rm -rf "$ROT"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
