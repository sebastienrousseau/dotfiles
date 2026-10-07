#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# lib/dot/theme-niri.sh: the niri target of dot-theme-sync. A managed
# config.kdl is recognised through `chezmoi managed`; an unmanaged one is
# rendered from the template, or declined with a note, never fatally.
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/theme-niri.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR" "$WORK/src/dot_config/niri" "$WORK/home/.config/niri"
CHEZMOI_SRC="$WORK/src"
TARGET="$WORK/home/.config/niri/config.kdl"
TEMPLATE="$CHEZMOI_SRC/dot_config/niri/config.kdl.tmpl"
NOTES="$WORK/notes"
_skip() { printf '%s: %s\n' "$1" "$2" >>"$NOTES"; }
# chezmoi stand-in: FAKE_MANAGED lists managed targets; FAKE_RENDER_RC is
# the execute-template exit status; a render echoes its input plus a mark.
chezmoi() {
  case "$1" in
    managed) printf '%s\n' "${FAKE_MANAGED:-}" ;;
    execute-template)
      cat
      printf '# rendered\n'
      return "${FAKE_RENDER_RC:-0}"
      ;;
    *) return 2 ;;
  esac
}
source "$REPO_ROOT/lib/dot/theme-niri.sh"

test_start "niri_managed_only_when_chezmoi_lists_the_target"
FAKE_MANAGED="$TARGET"
assert_true "_theme_niri_managed '$TARGET'" "listed target is managed"
FAKE_MANAGED="$WORK/home/.config/niri/other.kdl"
assert_false "_theme_niri_managed '$TARGET'" "another path listed does not count"
FAKE_MANAGED=""
assert_false "_theme_niri_managed '$TARGET'" "nothing listed: not managed"

test_start "niri_unmanaged_config_is_rendered_from_the_template"
: >"$NOTES"
printf 'old\n' >"$TARGET"
printf 'theme {{ .theme }}\n' >"$TEMPLATE"
_theme_render_niri_template "$TARGET"
assert_equals 0 $? "render succeeds"
assert_equals $'theme {{ .theme }}\n# rendered' "$(cat "$TARGET")" "the rendered template replaces the file"
assert_equals "" "$(cat "$NOTES")" "nothing to note"
assert_equals "" "$(ls -A "$TMPDIR")" "no temp file left behind"

test_start "niri_without_a_template_is_declined_with_a_note"
: >"$NOTES"
rm "$TEMPLATE"
printf 'hand kept\n' >"$TARGET"
_theme_render_niri_template "$TARGET"
assert_equals 1 $? "declined"
assert_equals "hand kept" "$(cat "$TARGET")" "the file is untouched"
assert_contains "no template to render" "$(cat "$NOTES")" "the note says why"

test_start "niri_render_failure_is_declined_and_leaves_the_file"
: >"$NOTES"
printf 'theme\n' >"$TEMPLATE"
printf 'hand kept\n' >"$TARGET"
FAKE_RENDER_RC=1 _theme_render_niri_template "$TARGET"
assert_equals 1 $? "declined"
assert_equals "hand kept" "$(cat "$TARGET")" "a failed render does not touch the file"
assert_contains "did not render" "$(cat "$NOTES")" "the note says why"
assert_equals "" "$(ls -A "$TMPDIR")" "the temp file is removed"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
