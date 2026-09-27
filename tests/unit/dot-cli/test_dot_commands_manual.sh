#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/manual.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "manual.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Each format resolves to its own file: seed an offline copy, then
# `download --offline` must copy exactly that file into the cwd.
MAN_TMP="$DOTFILES_COV_TMPDIR/manual"
mkdir -p "$MAN_TMP/data/dotfiles/manual/html"
for f in dotfiles.html dotfiles.pdf dotfiles.epub dotfiles.txt dotfiles-md.tar.gz html/index.html; do
  printf 'fixture %s\n' "$f" >"$MAN_TMP/data/dotfiles/manual/$f"
done
for pair in html:dotfiles.html pdf:dotfiles.pdf epub:dotfiles.epub text:dotfiles.txt markdown:dotfiles-md.tar.gz; do
  fmt="${pair%%:*}" want="${pair#*:}"
  test_start "download_offline_${fmt}"
  rm -rf "$MAN_TMP/cwd" && mkdir -p "$MAN_TMP/cwd"
  (cd "$MAN_TMP/cwd" && XDG_DATA_HOME="$MAN_TMP/data" bash "$SCRIPT_FILE" download "$fmt" --offline >/dev/null 2>&1) || true
  assert_equals "fixture $want" "$(cat "$MAN_TMP/cwd/$want" 2>/dev/null)" "$fmt downloads $want"
done

test_start "offline_missing_copy_fails"
assert_exit_code 1 "XDG_DATA_HOME='$MAN_TMP/empty' bash '$SCRIPT_FILE' download pdf --offline"

test_start "text_format_goes_to_pager"
assert_output_contains "fixture dotfiles.txt" "XDG_DATA_HOME='$MAN_TMP/data' PAGER=cat bash '$SCRIPT_FILE' text --offline"

test_start "uses_system_open_on_darwin"
assert_file_contains "$SCRIPT_FILE" "/usr/bin/open" "must use /usr/bin/open explicitly to avoid recursion"

test_start "registered_in_dot_cli"
DOT_BIN="$REPO_ROOT/bin/dot"
rm -rf "$MAN_TMP/cwd" && mkdir -p "$MAN_TMP/cwd"
(cd "$MAN_TMP/cwd" && XDG_DATA_HOME="$MAN_TMP/data" bash "$DOT_BIN" manual download epub --offline >/dev/null 2>&1) || true
assert_equals "fixture dotfiles.epub" "$(cat "$MAN_TMP/cwd/dotfiles.epub" 2>/dev/null)" "dot manual routes to manual.sh"

test_start "help_shows_usage_without_license_header"
assert_equals "dot manual — open or download the dotfiles manual in multiple formats.|0" \
  "$(bash "$SCRIPT_FILE" --help | head -1)|$(bash "$SCRIPT_FILE" --help | grep -c SPDX)" "help starts at the usage block"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
