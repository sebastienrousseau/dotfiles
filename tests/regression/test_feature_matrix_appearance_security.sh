#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the appearance.sh and security.sh
# command groups — theme, wallpaper, fonts, tune, backup, encrypt-check,
# firewall, telemetry, dns-doh, lock-screen, usb-safety and policy.
#
# This is the group with the highest proportion of "unmeasurable" rows, and
# the reason is the same for nearly all of them: applying a theme, setting a
# wallpaper, installing a font, tuning the OS or hardening the firewall
# changes the developer's actual machine, usually through sudo, osascript or
# `defaults write`. Those rows carry a --help smoke test and a recorded
# reason in the matrix rather than a fake pass.
#
# `dot theme set` is worth calling out: it resolves the theme file from the
# location of the sourced library, not from $HOME, so it rewrites
# defaults/.chezmoidata.toml in the CHECKOUT even under a sandboxed HOME —
# and then drives the OS appearance. It is never invoked here.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# ── theme (read-only rows) ─────────────────────────────────────────────────

test_fm_theme() {
  test_start "fm_theme"
  fm_run theme
  fm_expect_rc_in 0 1
  test_start "fm_theme_no_breakage"
  fm_expect_no_forbidden
}

test_fm_theme_list() {
  test_start "fm_theme_list"
  fm_run theme list
  fm_expect_rc_in 0 1
  test_start "fm_theme_list_is_populated"
  fm_expect_nonempty
  test_start "fm_theme_list_has_a_source_column"
  fm_expect_any "SOURCE" "WALLPAPER" "System"
}

test_fm_theme_current() {
  test_start "fm_theme_current"
  fm_run theme current
  fm_expect_rc_in 0 1
  test_start "fm_theme_current_names_the_active_theme"
  fm_expect_any "Current" "dark" "light"
  test_start "fm_theme_current_matches_chezmoidata"
  # The reported theme must be the one recorded in .chezmoidata.toml.
  local configured
  configured="$(sed -n 's/^theme = "\(.*\)"/\1/p' \
    "$REPO_ROOT/defaults/.chezmoidata.toml" | head -1)"
  if [[ -z "$configured" ]]; then
    fm_pass "skipped — no theme key in .chezmoidata.toml"
  elif [[ "$FM_OUT" == *"$configured"* ]]; then
    fm_pass "reported '$configured'"
  else
    fm_fail "current theme does not match .chezmoidata.toml ('$configured')"
  fi
}

test_fm_theme_set_missing() {
  # `dot theme set` with no name must not quietly apply a theme.
  #
  # This row deliberately does NOT assert an exit code, because the exit code
  # is not a property of the command here — it is a property of the bash
  # running it. scripts/theme/switch.sh installs `trap cleanup EXIT`, and when
  # the script aborts under `set -u` the trap's own (successful) last command
  # replaces the failure status on bash 3.2 but not on bash 5.x:
  #
  #     bash 3.2  (macOS runners, /bin/bash)   rc=0
  #     bash 5.x  (Linux runners)              rc=1
  #
  # Measured directly, and with the trap removed both return 1. An earlier
  # version of this row asserted "must not exit 0" and so passed on Linux and
  # failed on macOS while the command behaved identically on both — a test of
  # the runner, not of the CLI.
  #
  # Two product findings reported separately, neither fixed here:
  #   * `dot help theme` documents "interactive picker if omitted", but
  #     `set_theme "$1"` dies on the unset positional before pick_theme is
  #     ever reached. `"${1:-}"` would restore the documented behaviour.
  #   * More seriously, that EXIT trap masks the exit status of ANY failure in
  #     switch.sh on bash 3.2, so on macOS the script reports success however
  #     it fails.
  #
  # What is contractual on both platforms, and what this row pins: the command
  # says something rather than failing mute, and it does not change the
  # configured theme.
  local data="$REPO_ROOT/defaults/.chezmoidata.toml"
  local before
  before="$(sed -n 's/^theme = "\(.*\)"/\1/p' "$data" | head -1)"

  test_start "fm_theme_set_missing"
  fm_run theme set
  if [[ -n "$FM_OUT$FM_ERR" ]]; then
    fm_pass "reported a diagnostic (rc=$FM_RC)"
  else
    fm_fail "theme set with no name produced no output at all"
  fi

  test_start "fm_theme_set_missing_does_not_apply_a_theme"
  local after
  after="$(sed -n 's/^theme = "\(.*\)"/\1/p' "$data" | head -1)"
  if [[ "$before" == "$after" ]]; then
    fm_pass "theme still ${before:-unset}"
  else
    fm_fail "theme changed from ${before:-unset} to ${after:-unset} with no name given"
  fi
}

test_fm_smoke_theme_set() { fm_smoke theme; }
test_fm_smoke_theme_toggle() { fm_smoke theme; }
test_fm_smoke_theme_sync() { fm_smoke theme; }
test_fm_smoke_theme_family() { fm_smoke theme; }
test_fm_smoke_theme_rebuild() { fm_smoke theme; }

# ── wallpaper / fonts / tune ───────────────────────────────────────────────

test_fm_smoke_wallpaper() { fm_smoke wallpaper; }
test_fm_smoke_wallpaper_sync() { fm_smoke wallpaper; }
test_fm_smoke_wallpaper_rotate() { fm_smoke wallpaper; }
test_fm_smoke_fonts() { fm_smoke fonts; }
test_fm_smoke_fonts_install() { fm_smoke fonts; }
test_fm_smoke_tune() { fm_smoke tune; }

test_fm_fonts_patch_usage() {
  # `fonts patch` with no font file must print its usage rather than
  # patching something implicit — the one fonts path reachable offline.
  test_start "fm_fonts_patch_usage"
  fm_run fonts patch
  fm_expect_rc 1
  test_start "fm_fonts_patch_usage_message"
  fm_expect_any "Usage" "font-file"
}

# ── security ───────────────────────────────────────────────────────────────

test_fm_backup() {
  # DOTFILES_BACKUP_SRC/DIR keep the archive inside the sandbox instead of
  # tarring the developer's real home.
  local src="$FM_SANDBOX/work/backup-src"
  local dest="$FM_SANDBOX/work/backup-dest"
  mkdir -p "$src/nested" "$dest"
  printf 'payload\n' >"$src/nested/file.txt"
  test_start "fm_backup"
  DOTFILES_BACKUP_SRC="$src" DOTFILES_BACKUP_DIR="$dest" fm_run backup
  fm_expect_rc_in 0 1
  test_start "fm_backup_writes_an_archive"
  if find "$dest" -name '*.tgz' 2>/dev/null | grep -q .; then
    fm_pass "archive written under DOTFILES_BACKUP_DIR"
  else
    fm_fail "no .tgz under $dest"
  fi
}

test_fm_encrypt_check() {
  test_start "fm_encrypt_check"
  fm_run encrypt-check
  fm_expect_rc_in 0 1
  test_start "fm_encrypt_check_reports_a_verdict"
  fm_expect_any "Encryption" "FileVault" "LUKS" "encryption"
}

test_fm_telemetry() {
  # Opt-in by design: without DOTFILES_TELEMETRY=1 the command must refuse
  # and say how to enable it, rather than disabling OS services silently.
  test_start "fm_telemetry"
  fm_run telemetry
  fm_expect_rc_in 0 1
  test_start "fm_telemetry_is_opt_in"
  fm_expect_any "disabled by default" "DOTFILES_TELEMETRY"
}

test_fm_policy() {
  test_start "fm_policy"
  fm_run policy
  # Exits non-zero when opa/gitleaks are absent, which is the environment
  # rather than a regression; what matters is the dependency check runs.
  fm_expect_rc_in 0 1
  test_start "fm_policy_runs_the_enforcement_pass"
  fm_expect_any "security policy" "Checking dependencies" "policy"
}

test_fm_smoke_firewall() { fm_smoke firewall; }
test_fm_smoke_telemetry_apply() { fm_smoke telemetry; }
test_fm_smoke_dns_doh() { fm_smoke dns-doh; }
test_fm_smoke_lock_screen() { fm_smoke lock-screen; }
test_fm_smoke_usb_safety() { fm_smoke usb-safety; }

# The whole point of the smoke rows above is that asking for help must not
# perform the command. Prove it once, on the sharpest case: `dot firewall
# --help` must not have invoked sudo.
test_fm_security_help_does_not_mutate() {
  fm_stub sudo "printf 'SUDO %s\\n' \"\$*\" >>'$FM_SANDBOX/sudo-calls.log'"
  rm -f "$FM_SANDBOX/sudo-calls.log"
  local cmd
  for cmd in firewall telemetry dns-doh lock-screen usb-safety tune; do
    fm_run "$cmd" --help
  done
  test_start "fm_security_help_does_not_mutate"
  if [[ -e "$FM_SANDBOX/sudo-calls.log" ]]; then
    fm_fail "a --help invocation called sudo: $(head -1 "$FM_SANDBOX/sudo-calls.log")"
  else
    fm_pass "no sudo call from any security --help"
  fi
  fm_stub sudo 'exit 0'
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: appearance + security ──"
echo ""

test_fm_theme
test_fm_theme_list
test_fm_theme_current
test_fm_theme_set_missing
test_fm_smoke_theme_set
test_fm_smoke_theme_toggle
test_fm_smoke_theme_sync
test_fm_smoke_theme_family
test_fm_smoke_theme_rebuild
test_fm_smoke_wallpaper
test_fm_smoke_wallpaper_sync
test_fm_smoke_wallpaper_rotate
test_fm_smoke_fonts
test_fm_smoke_fonts_install
test_fm_fonts_patch_usage
test_fm_smoke_tune
test_fm_backup
test_fm_encrypt_check
test_fm_telemetry
test_fm_policy
test_fm_smoke_firewall
test_fm_smoke_telemetry_apply
test_fm_smoke_dns_doh
test_fm_smoke_lock_screen
test_fm_smoke_usb_safety
test_fm_security_help_does_not_mutate

fm_finish
