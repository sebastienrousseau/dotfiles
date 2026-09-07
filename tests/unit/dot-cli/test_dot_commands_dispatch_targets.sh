#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for the two thin dispatch command files:
#   scripts/dot/commands/appearance.sh  (theme, wallpaper, fonts, tune)
#   scripts/dot/commands/security.sh    (backup, encrypt-check, firewall,
#                                        telemetry, dns-doh, lock-screen,
#                                        usb-safety, policy)
#
# Both are pure routers: each subcommand resolves the dotfiles source tree
# and then `exec bash <script>`. What matters is that the right target is
# chosen and the arguments survive, so `bash` is PATH-shadowed with a shim
# that records the hand-off instead of performing it — none of the real
# firewall / tuning / wallpaper scripts ever run.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

APPEARANCE="$REPO_ROOT/scripts/dot/commands/appearance.sh"
SECURITY="$REPO_ROOT/scripts/dot/commands/security.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_UNAME="$(command -v uname)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "command_files_exist"
assert_file_exists "$APPEARANCE" "scripts/dot/commands/appearance.sh must exist"
assert_file_exists "$SECURITY" "scripts/dot/commands/security.sh must exist"

# The hand-off shim: anything under scripts/ is recorded rather than run,
# everything else (the command file itself, helper subshells) reaches the
# real interpreter.
cat >"$BIN/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  */scripts/theme/*|*/scripts/fonts/*|*/scripts/tuning/*|*/scripts/security/*)
    printf 'dispatched %s %s\n' "\${1#$REPO_ROOT/}" "\${*:2}"
    exit "\${DISPATCH_RC:-0}"
    ;;
esac
exec "$REAL_BASH" "\$@"
EOF
cat >"$BIN/uname" <<EOF
#!$REAL_BASH
if [[ -n "\${FAKE_UNAME:-}" && "\${1:-}" == "-s" ]]; then echo "\$FAKE_UNAME"; exit 0; fi
exec "$REAL_UNAME" "\$@"
EOF
chmod +x "$BIN/bash" "$BIN/uname"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# dispatch <command-file> <args…> — run a command file with the shim on
# PATH. Stdout is captured; stderr is replayed so the coverage runner still
# sees its xtrace records. Echoes the exit status.
dispatch() {
  local file="$1" rc=0
  shift
  PATH="$BIN:/usr/bin:/bin" DOTFILES_SHOW_LOGO=0 \
    "$REAL_BASH" "$file" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# appearance.sh
# ===========================================================================
test_start "appearance_usage_on_help_and_no_args"
rc="$(dispatch "$APPEARANCE" --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "theme, wallpaper, fonts, tune" "usage lists the subcommands"
for flag in -h help; do
  rc="$(dispatch "$APPEARANCE" "$flag")"
  assert_equals "0" "$rc" "$flag exits 0"
done
rc="$(dispatch "$APPEARANCE")"
assert_equals "1" "$rc" "no arguments is a usage error"
assert_file_contains "$OUT" "Usage: appearance.sh" "usage is still printed"

test_start "appearance_rejects_an_unknown_subcommand"
rc="$(dispatch "$APPEARANCE" not-a-subcommand)"
assert_equals "1" "$rc" "an unknown subcommand fails"
assert_file_contains "$ERR" "Unknown appearance command" "the error names the command"

test_start "appearance_theme_routes_to_the_switcher"
rc="$(dispatch "$APPEARANCE" theme list)"
assert_equals "0" "$rc" "theme exits 0"
assert_file_contains "$OUT" "dispatched scripts/theme/switch.sh list" "theme routes to switch.sh with its arguments"

test_start "appearance_wallpaper_defaults_to_sync"
dispatch "$APPEARANCE" wallpaper >/dev/null
assert_file_contains "$OUT" "dispatched scripts/theme/wallpaper-sync.sh" "a bare wallpaper syncs"
dispatch "$APPEARANCE" wallpaper sync --dry-run >/dev/null
assert_file_contains "$OUT" "dispatched scripts/theme/wallpaper-sync.sh --dry-run" "explicit sync forwards flags"

test_start "appearance_wallpaper_rotate_routes_to_the_rotator"
dispatch "$APPEARANCE" wallpaper rotate --next >/dev/null
assert_file_contains "$OUT" "dispatched scripts/theme/wallpaper-rotate.sh --next" "rotate routes to wallpaper-rotate.sh"

test_start "appearance_wallpaper_unknown_argument_falls_back_to_sync"
dispatch "$APPEARANCE" wallpaper somefile.heic >/dev/null
assert_file_contains "$OUT" "dispatched scripts/theme/wallpaper-sync.sh somefile.heic" "an unrecognised argument is passed to sync"

test_start "appearance_fonts_defaults_to_install"
dispatch "$APPEARANCE" fonts >/dev/null
assert_file_contains "$OUT" "dispatched scripts/fonts/install-nerd-fonts.sh" "a bare fonts installs"
dispatch "$APPEARANCE" fonts install --all >/dev/null
assert_file_contains "$OUT" "dispatched scripts/fonts/install-nerd-fonts.sh --all" "explicit install forwards flags"

test_start "appearance_fonts_patch_routes_to_the_patcher"
dispatch "$APPEARANCE" fonts patch MyFont.ttf >/dev/null
assert_file_contains "$OUT" "dispatched scripts/fonts/patch-fonts.sh MyFont.ttf" "patch routes to patch-fonts.sh"

test_start "appearance_fonts_unknown_argument_falls_back_to_install"
dispatch "$APPEARANCE" fonts JetBrains >/dev/null
assert_file_contains "$OUT" "dispatched scripts/fonts/install-nerd-fonts.sh JetBrains" "an unrecognised argument is passed to the installer"

test_start "appearance_tune_selects_the_platform_script"
FAKE_UNAME=Darwin dispatch "$APPEARANCE" tune --dry-run >/dev/null
assert_file_contains "$OUT" "dispatched scripts/tuning/macos.sh --dry-run" "macOS tunes with the macOS script"
FAKE_UNAME=Linux dispatch "$APPEARANCE" tune >/dev/null
assert_file_contains "$OUT" "dispatched scripts/tuning/linux.sh" "Linux tunes with the Linux script"

test_start "appearance_tune_refuses_an_unsupported_platform"
rc="$(FAKE_UNAME=SunOS dispatch "$APPEARANCE" tune)"
assert_equals "1" "$rc" "an unsupported platform fails"
assert_file_contains "$OUT" "not supported on this platform" "the refusal explains why"

test_start "appearance_propagates_the_target_exit_status"
rc="$(DISPATCH_RC=3 dispatch "$APPEARANCE" theme list)"
assert_equals "3" "$rc" "the target script's exit status is the command's exit status"

# ===========================================================================
# security.sh
# ===========================================================================
test_start "security_usage_on_help_and_no_args"
rc="$(dispatch "$SECURITY" --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "usb-safety, policy" "usage lists the subcommands"
for flag in -h help; do
  rc="$(dispatch "$SECURITY" "$flag")"
  assert_equals "0" "$rc" "$flag exits 0"
done
rc="$(dispatch "$SECURITY")"
assert_equals "1" "$rc" "no arguments is a usage error"

test_start "security_rejects_an_unknown_subcommand"
rc="$(dispatch "$SECURITY" not-a-subcommand)"
assert_equals "1" "$rc" "an unknown subcommand fails"
assert_file_contains "$ERR" "Unknown security command" "the error names the command"

test_start "security_subcommands_route_to_their_scripts"
# subcommand → target script, with an argument to prove forwarding.
while IFS='|' read -r sub target; do
  [[ -n "$sub" ]] || continue
  dispatch "$SECURITY" "$sub" --dry-run >/dev/null
  assert_file_contains "$OUT" "dispatched scripts/security/$target --dry-run" \
    "$sub routes to $target"
done <<'ROUTES'
backup|backup.sh
encrypt-check|encryption-check.sh
firewall|firewall.sh
telemetry|telemetry-kill.sh
dns-doh|dns-doh.sh
lock-screen|lock-screen.sh
usb-safety|usb-safety.sh
policy|enforce-policies.sh
ROUTES

test_start "security_propagates_the_target_exit_status"
rc="$(DISPATCH_RC=2 dispatch "$SECURITY" firewall)"
assert_equals "2" "$rc" "the target script's exit status is the command's exit status"

test_start "security_reports_a_missing_target_script"
# run_script falls back to the repo root and then gives up; point the
# resolver at a tree that has neither.
EMPTY_TREE="$WORK/empty-tree/lib/dot"
mkdir -p "$EMPTY_TREE"
for lib in ui.sh utils.sh platform.sh ai-install.sh log.sh verified-download.sh; do
  ln -sf "$REPO_ROOT/lib/dot/$lib" "$EMPTY_TREE/$lib"
done
mkdir -p "$WORK/empty-tree/scripts/dot/commands"
ln -sf "$SECURITY" "$WORK/empty-tree/scripts/dot/commands/security.sh"
rc=0
PATH="$BIN:/usr/bin:/bin" DOTFILES_SHOW_LOGO=0 HOME="$WORK/empty-home" \
  CHEZMOI_SOURCE_DIR="$WORK/empty-tree" \
  "$REAL_BASH" "$WORK/empty-tree/scripts/dot/commands/security.sh" backup \
  >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "1" "$rc" "a missing target script is an error"
assert_file_contains "$ERR" "not found" "the error says the script was not found"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
