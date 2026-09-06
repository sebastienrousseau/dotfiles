#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for the four boot/desktop theming installers:
#
#   scripts/theme/install-grub-theme.sh
#   scripts/theme/install-boot-logo.sh
#   scripts/theme/install-lock-icon.sh
#   scripts/theme/install-cursors.sh
#
# All four are Linux-only and the first two additionally require root, so
# the tests drive the platform gate, the missing-asset guards, the dry-run
# default and the not-root refusal. `uname` and `gsettings` are
# PATH-shadowed; the scripts' privileged halves (writing /boot, /etc/default
# and running update-grub or plymouth) are not reachable without root and
# are recorded as such in the coverage report rather than faked.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

GRUB="$REPO_ROOT/scripts/theme/install-grub-theme.sh"
BOOT_LOGO="$REPO_ROOT/scripts/theme/install-boot-logo.sh"
LOCK_ICON="$REPO_ROOT/scripts/theme/install-lock-icon.sh"
CURSORS="$REPO_ROOT/scripts/theme/install-cursors.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_UNAME="$(command -v uname)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "installer_scripts_exist"
for f in "$GRUB" "$BOOT_LOGO" "$LOCK_ICON" "$CURSORS"; do
  assert_file_exists "$f" "$(basename "$f") must exist"
done

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
chmod +x "$BIN/uname" "$BIN/gsettings"
# swaylock / i3lock exist only when a test links them in.
LOCKTOOLS="$WORK/locktools"
mkdir -p "$LOCKTOOLS"
for tool in swaylock i3lock; do
  cat >"$LOCKTOOLS/$tool" <<EOF
#!$REAL_BASH
exit 0
EOF
  chmod +x "$LOCKTOOLS/$tool"
done

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# run <script> <args…> — stdout captured, stderr replayed so the coverage
# runner keeps its xtrace records. Echoes the exit status.
run() {
  local script="$1" rc=0
  shift
  PATH="${EXTRA_PATH:+$EXTRA_PATH:}$BIN:/usr/bin:/bin" \
    "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# install-grub-theme.sh
# ===========================================================================
test_start "grub_theme_is_linux_only"
rc="$(FAKE_UNAME=Darwin run "$GRUB")"
assert_equals "0" "$rc" "a non-Linux host exits 0 without doing anything"
assert_file_contains "$ERR" "GRUB theming is Linux-only" "the refusal explains why"

test_start "grub_theme_requires_a_theme_directory"
rc="$(FAKE_UNAME=Linux DOTFILES_GRUB_THEME_DIR="$WORK/absent" run "$GRUB")"
assert_equals "1" "$rc" "a missing theme directory fails"
assert_file_contains "$ERR" "Theme directory not found" "the error names the problem"
assert_file_contains "$ERR" "DOTFILES_GRUB_THEME_DIR" "the error names the override"

test_start "grub_theme_defaults_to_a_dry_run"
GRUB_SRC="$WORK/grub-theme"
mkdir -p "$GRUB_SRC"
printf 'theme\n' >"$GRUB_SRC/theme.txt"
rc="$(FAKE_UNAME=Linux DOTFILES_GRUB_THEME_DIR="$GRUB_SRC" run "$GRUB")"
assert_equals "0" "$rc" "the dry run exits 0"
assert_file_contains "$ERR" "Dry run. Use --apply" "the dry run says how to proceed"

test_start "grub_theme_apply_requires_root"
rc="$(FAKE_UNAME=Linux DOTFILES_GRUB_THEME_DIR="$GRUB_SRC" run "$GRUB" --apply)"
assert_equals "1" "$rc" "--apply without root fails"
assert_file_contains "$ERR" "run with sudo" "the error asks for sudo"

# ===========================================================================
# install-boot-logo.sh
# ===========================================================================
test_start "boot_logo_is_linux_only"
rc="$(FAKE_UNAME=Darwin run "$BOOT_LOGO")"
assert_equals "0" "$rc" "a non-Linux host exits 0 without doing anything"
assert_file_contains "$ERR" "Boot logo customization is Linux-only" "the refusal explains why"

test_start "boot_logo_requires_the_image"
rc="$(FAKE_UNAME=Linux DOTFILES_BOOT_LOGO="$WORK/absent.png" run "$BOOT_LOGO")"
assert_equals "1" "$rc" "a missing logo fails"
assert_file_contains "$ERR" "Boot logo not found" "the error names the problem"
assert_file_contains "$ERR" "DOTFILES_BOOT_LOGO" "the error names the override"

test_start "boot_logo_defaults_to_a_dry_run"
LOGO="$WORK/logo.png"
: >"$LOGO"
rc="$(FAKE_UNAME=Linux DOTFILES_BOOT_LOGO="$LOGO" run "$BOOT_LOGO")"
assert_equals "0" "$rc" "the dry run exits 0"
assert_file_contains "$ERR" "Dry run. Use --apply" "the dry run says how to proceed"

test_start "boot_logo_apply_requires_root"
rc="$(FAKE_UNAME=Linux DOTFILES_BOOT_LOGO="$LOGO" run "$BOOT_LOGO" --apply)"
assert_equals "1" "$rc" "--apply without root fails"
assert_file_contains "$ERR" "run with sudo" "the error asks for sudo"

# ===========================================================================
# install-lock-icon.sh
# ===========================================================================
test_start "lock_icon_requires_the_image"
rc="$(DOTFILES_LOCK_ICON="$WORK/absent.png" run "$LOCK_ICON")"
assert_equals "1" "$rc" "a missing icon fails"
assert_file_contains "$ERR" "Lock icon not found" "the error names the problem"

test_start "lock_icon_is_unsupported_on_macos"
ICON="$WORK/icon.png"
: >"$ICON"
rc="$(FAKE_UNAME=Darwin DOTFILES_LOCK_ICON="$ICON" run "$LOCK_ICON")"
assert_equals "0" "$rc" "macOS exits 0"
assert_file_contains "$ERR" "not supported via script on macOS" "the refusal explains why"

test_start "lock_icon_suggests_the_available_locker_on_linux"
rc="$(EXTRA_PATH="$LOCKTOOLS" FAKE_UNAME=Linux DOTFILES_LOCK_ICON="$ICON" run "$LOCK_ICON")"
assert_equals "0" "$rc" "the Linux path exits 0"
assert_file_contains "$OUT" "swaylock --image" "swaylock is suggested when present"

test_start "lock_icon_falls_back_to_i3lock_then_reports_neither"
I3ONLY="$WORK/i3only"
mkdir -p "$I3ONLY"
ln -sf "$LOCKTOOLS/i3lock" "$I3ONLY/i3lock"
rc="$(EXTRA_PATH="$I3ONLY" FAKE_UNAME=Linux DOTFILES_LOCK_ICON="$ICON" run "$LOCK_ICON")"
assert_equals "0" "$rc" "the i3lock path exits 0"
assert_file_contains "$OUT" "i3lock -i" "i3lock is suggested when swaylock is absent"
rc="$(FAKE_UNAME=Linux DOTFILES_LOCK_ICON="$ICON" run "$LOCK_ICON")"
assert_equals "0" "$rc" "no locker at all still exits 0"
assert_file_contains "$ERR" "No supported lock screen tool" "the absence is reported"

test_start "lock_icon_reports_an_unsupported_platform"
rc="$(FAKE_UNAME=SunOS DOTFILES_LOCK_ICON="$ICON" run "$LOCK_ICON")"
assert_equals "0" "$rc" "an unknown platform exits 0"
assert_file_contains "$ERR" "Unsupported OS for lock icon" "the platform is named as unsupported"

# ===========================================================================
# install-cursors.sh
# ===========================================================================
test_start "cursors_are_unsupported_on_macos"
rc="$(FAKE_UNAME=Darwin run "$CURSORS")"
assert_equals "0" "$rc" "macOS exits 0"
assert_file_contains "$ERR" "not supported via script on macOS" "the refusal explains why"

test_start "cursors_are_applied_through_gsettings_on_linux"
: >"$CALLS"
rc="$(FAKE_UNAME=Linux run "$CURSORS")"
assert_equals "0" "$rc" "the Linux path exits 0"
assert_file_contains "$CALLS" "gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Ice" "the default theme is applied"
assert_file_contains "$CALLS" "cursor-size 24" "the default size is applied"
assert_file_contains "$OUT" "Set GNOME cursor theme" "the change is reported"

test_start "cursor_theme_and_size_can_be_overridden"
: >"$CALLS"
DOTFILES_CURSOR_THEME=Adwaita DOTFILES_CURSOR_SIZE=48 FAKE_UNAME=Linux run "$CURSORS" >/dev/null
assert_file_contains "$CALLS" "cursor-theme Adwaita" "the theme override is honoured"
assert_file_contains "$CALLS" "cursor-size 48" "the size override is honoured"

test_start "cursors_report_a_missing_gsettings"
NOGS="$WORK/nogsettings"
mkdir -p "$NOGS"
ln -sf "$REAL_BASH" "$NOGS/bash"
ln -sf "$BIN/uname" "$NOGS/uname"
rc=0
PATH="$NOGS" FAKE_UNAME=Linux "$REAL_BASH" "$CURSORS" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "a missing gsettings is not fatal"
assert_file_contains "$ERR" "gsettings not found" "the user is told to set the theme by hand"

test_start "cursors_report_an_unsupported_platform"
rc="$(FAKE_UNAME=SunOS run "$CURSORS")"
assert_equals "0" "$rc" "an unknown platform exits 0"
assert_file_contains "$ERR" "Unsupported OS for cursor theming" "the platform is named as unsupported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
