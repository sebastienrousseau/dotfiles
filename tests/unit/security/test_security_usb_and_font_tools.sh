#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for two opt-in system tools:
#
#   scripts/security/usb-safety.sh   disable removable-media automount
#   scripts/fonts/patch-fonts.sh     patch a font with Nerd Font glyphs
#
# usb-safety only acts when DOTFILES_USB_SAFETY=1, and its one mutation
# (gsettings) is PATH-shadowed here; patch-fonts shells out to fontforge,
# which is stubbed. Neither test changes any desktop setting or writes a
# font outside the sandbox.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

USB="$REPO_ROOT/scripts/security/usb-safety.sh"
PATCH="$REPO_ROOT/scripts/fonts/patch-fonts.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_UNAME="$(command -v uname)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "scripts_exist"
assert_file_exists "$USB" "scripts/security/usb-safety.sh must exist"
assert_file_exists "$PATCH" "scripts/fonts/patch-fonts.sh must exist"

CALLS="$WORK/calls"
: >"$CALLS"
cat >"$BIN/uname" <<EOF
#!$REAL_BASH
if [[ -n "\${FAKE_UNAME:-}" && "\${1:-}" == "-s" ]]; then echo "\$FAKE_UNAME"; exit 0; fi
exec "$REAL_UNAME" "\$@"
EOF
cat >"$BIN/gsettings" <<EOF
#!$REAL_BASH
printf 'gsettings %s\n' "\$*" >>"$CALLS"
exit 0
EOF
cat >"$BIN/fontforge" <<EOF
#!$REAL_BASH
printf 'fontforge %s\n' "\$*" >>"$CALLS"
exit "\${FAKE_FONTFORGE_RC:-0}"
EOF
chmod +x "$BIN/uname" "$BIN/gsettings" "$BIN/fontforge"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
run() {
  local script="$1" rc=0
  shift
  PATH="${SCRIPT_PATH:-$BIN:/usr/bin:/bin}" \
    "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# usb-safety.sh
# ===========================================================================
test_start "usb_safety_is_disabled_unless_opted_in"
rc="$(run "$USB")"
assert_equals "1" "$rc" "the default is to do nothing and fail"
assert_file_contains "$OUT" "disabled by default" "the opt-out is explained"
assert_file_contains "$OUT" "DOTFILES_USB_SAFETY=1" "the opt-in variable is named"

test_start "usb_safety_dry_run_describes_the_change"
: >"$CALLS"
rc="$(FAKE_UNAME=Linux run "$USB" --dry-run)"
assert_equals "0" "$rc" "a dry run exits 0"
assert_file_contains "$OUT" "dry-run (no changes will be made)" "the mode is announced"
assert_file_contains "$OUT" "automount false" "the change is described"
assert_output_not_contains "gsettings set" "cat '$CALLS'"

test_start "usb_safety_short_flag_is_also_a_dry_run"
: >"$CALLS"
rc="$(FAKE_UNAME=Linux run "$USB" -n)"
assert_equals "0" "$rc" "-n exits 0"
assert_output_not_contains "gsettings set" "cat '$CALLS'"

test_start "usb_safety_applies_the_gnome_settings_when_opted_in"
: >"$CALLS"
rc="$(DOTFILES_USB_SAFETY=1 FAKE_UNAME=Linux run "$USB")"
assert_equals "0" "$rc" "the opted-in run exits 0"
assert_file_contains "$CALLS" "gsettings set org.gnome.desktop.media-handling automount false" "automount is disabled"
assert_file_contains "$CALLS" "automount-open false" "automount-open is disabled too"

test_start "usb_safety_reports_a_missing_gsettings"
NOGS="$WORK/nogsettings"
mkdir -p "$NOGS"
for tool in bash sh printf cat grep sed awk locale dirname uname; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOGS/$tool"
done
ln -sf "$BIN/uname" "$NOGS/uname"
rc="$(SCRIPT_PATH="$NOGS" DOTFILES_USB_SAFETY=1 FAKE_UNAME=Linux run "$USB")"
assert_equals "1" "$rc" "no gsettings is an error"
assert_file_contains "$OUT" "gsettings" "the missing tool is named"

test_start "usb_safety_explains_the_macos_situation"
rc="$(DOTFILES_USB_SAFETY=1 FAKE_UNAME=Darwin run "$USB")"
assert_equals "0" "$rc" "macOS exits 0"
assert_file_contains "$OUT" "no CLI toggle" "the limitation is explained"
assert_file_contains "$OUT" "System Settings" "the manual alternative is given"

test_start "usb_safety_refuses_an_unsupported_platform"
rc="$(DOTFILES_USB_SAFETY=1 FAKE_UNAME=SunOS run "$USB")"
assert_equals "1" "$rc" "an unsupported platform fails"
assert_file_contains "$OUT" "Unsupported OS" "the refusal names the platform"

# ===========================================================================
# patch-fonts.sh
# ===========================================================================
test_start "patch_fonts_requires_a_font_argument"
rc="$(run "$PATCH")"
assert_equals "1" "$rc" "no argument fails"
assert_file_contains "$ERR" "Usage: patch-fonts.sh" "usage is printed"

test_start "patch_fonts_requires_the_font_to_exist"
rc="$(run "$PATCH" "$WORK/absent.ttf")"
assert_equals "1" "$rc" "a missing font fails"
assert_file_contains "$ERR" "Font not found" "the error names the font"

test_start "patch_fonts_requires_fontforge"
FONT="$WORK/MyFont.ttf"
: >"$FONT"
NOFF="$WORK/nofontforge"
mkdir -p "$NOFF"
for tool in bash sh printf mkdir; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOFF/$tool"
done
rc="$(SCRIPT_PATH="$NOFF" run "$PATCH" "$FONT")"
assert_equals "1" "$rc" "a missing fontforge fails"
assert_file_contains "$ERR" "fontforge not found" "the error names the tool"

test_start "patch_fonts_requires_the_nerd_fonts_patcher"
rc="$(NERD_FONTS_PATCHER="$WORK/absent-patcher" run "$PATCH" "$FONT")"
assert_equals "1" "$rc" "a missing patcher fails"
assert_file_contains "$ERR" "Nerd Fonts patcher not found" "the error names the patcher"
assert_file_contains "$ERR" "NERD_FONTS_PATCHER" "the override variable is named"

test_start "patch_fonts_runs_the_patcher_into_the_output_directory"
PATCHER="$WORK/font-patcher"
printf '#!/usr/bin/env bash\nexit 0\n' >"$PATCHER"
chmod +x "$PATCHER"
OUTDIR="$WORK/patched"
: >"$CALLS"
rc="$(NERD_FONTS_PATCHER="$PATCHER" run "$PATCH" "$FONT" "$OUTDIR")"
assert_equals "0" "$rc" "patching exits 0"
assert_dir_exists "$OUTDIR" "the output directory is created"
assert_file_contains "$CALLS" "fontforge -script $PATCHER --complete --outputdir $OUTDIR $FONT" "the patcher is invoked with the expected arguments"
assert_file_contains "$OUT" "Patched font written to: $OUTDIR" "the destination is reported"

test_start "patch_fonts_defaults_the_output_directory_to_the_working_directory"
: >"$CALLS"
rc=0
(cd "$WORK" && PATH="$BIN:/usr/bin:/bin" NERD_FONTS_PATCHER="$PATCHER" \
  "$REAL_BASH" "$PATCH" "$FONT") >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the default destination exits 0"
assert_dir_exists "$WORK/patched-fonts" "patched-fonts is created beside the caller"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
