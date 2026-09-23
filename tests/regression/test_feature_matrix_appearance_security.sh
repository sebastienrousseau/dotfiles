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
# `dot theme set` is worth calling out: it resolves the theme file from
# CHEZMOI_SOURCE_DIR / $HOME/.dotfiles, which this harness aims at the
# checkout, and it then drives the real OS appearance. It is never invoked
# here with a theme name for that second reason.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# ── theme (read-only rows) ─────────────────────────────────────────────────

test_fm_theme() {
  # With no subcommand `dot theme` opens the picker. The harness captures
  # stderr, so ui_pick sees no tty, runs no selector (fzf/gum are gated on
  # `-t 2`, dot-ui on DOTFILES_NO_TUI) and reports that nothing changed —
  # the same outcome on every host, whether or not a picker is installed.
  test_start "fm_theme"
  fm_run theme
  fm_expect_rc 0
  test_start "fm_theme_reports_no_selection"
  fm_expect_out "no selection"
  test_start "fm_theme_still_names_the_configured_theme"
  fm_expect_out_matches 'still on [a-z0-9]+-(dark|light)'
  test_start "fm_theme_no_breakage"
  fm_expect_no_forbidden
}

test_fm_theme_list() {
  test_start "fm_theme_list"
  fm_run theme list
  fm_expect_rc 0
  test_start "fm_theme_list_is_populated"
  fm_expect_nonempty
  test_start "fm_theme_list_has_a_source_column"
  fm_expect_out_matches '^  WALLPAPER +SOURCE$'
  # WALLPAPER_DIR resolves under the sandbox HOME, which has no Pictures/
  # Wallpapers, so every family is "System" here and the active one carries
  # the ◀ marker.
  test_start "fm_theme_list_marks_the_current_family"
  fm_expect_out_matches '^  [^ ]+ +[a-z0-9]+ +System ◀'
  test_start "fm_theme_list_counts_the_families"
  fm_expect_out_matches 'Current +[a-z0-9]+-(dark|light) \([1-9][0-9]* wallpaper themes available\)'
}

test_fm_theme_current() {
  test_start "fm_theme_current"
  fm_run theme current
  fm_expect_rc 0
  test_start "fm_theme_current_names_the_active_theme"
  fm_expect_out_matches 'Current +[a-z0-9]+-(dark|light) \([a-z0-9]+, (dark|light); (auto|dark|light)\)'
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
  # History: this row used to avoid asserting an exit code, because the code
  # was a property of the bash running the command rather than of the command.
  # `set_theme "$1"` aborted on the unset positional under `set -u`, and a
  # script that dies that way with an EXIT trap installed — switch.sh installs
  # `trap cleanup EXIT` — exits 0 on bash 3.2 (macOS /bin/bash) and 1 on 5.x.
  # No handler can recover it: `$?` is already 0 when the handler runs.
  #
  # Both halves are fixed. `set_theme "${1:-}"` reaches the picker `dot help
  # theme` documents, so the abort — the only status-losing path on 3.2 — is
  # gone, and under DOTFILES_NONINTERACTIVE (which the sandbox exports, and
  # where no picker can run) the command refuses with a usage message and
  # rc=1 on every shell. tests/unit/theme/test_theme_switch_dispatch.sh pins
  # the picker path and the bash-3.2 status directly.
  local data="$REPO_ROOT/defaults/.chezmoidata.toml"
  local before
  before="$(sed -n 's/^theme = "\(.*\)"/\1/p' "$data" | head -1)"

  test_start "fm_theme_set_missing"
  fm_run theme set
  fm_expect_rc 1
  test_start "fm_theme_set_missing_reports_usage"
  fm_expect_any "dot theme set <name>" "Missing theme name"

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
  fm_expect_rc 0
  test_start "fm_backup_reports_the_archive_path"
  fm_expect_out "Backup written"
  test_start "fm_backup_reports_the_archive_under_backup_dir"
  fm_expect_out "$dest/dotfiles-backup-"
  test_start "fm_backup_writes_an_archive"
  local archive
  archive="$(find "$dest" -name '*.tgz' 2>/dev/null | head -1)"
  if [[ -n "$archive" ]]; then
    fm_pass "archive written under DOTFILES_BACKUP_DIR"
  else
    fm_fail "no .tgz under $dest"
  fi
  test_start "fm_backup_archives_the_source_tree"
  if [[ -n "$archive" ]] && tar -tzf "$archive" 2>/dev/null | grep -q 'nested/file\.txt$'; then
    fm_pass "nested/file.txt is in the archive"
  else
    fm_fail "DOTFILES_BACKUP_SRC content missing from the archive"
  fi
}

test_fm_encrypt_check() {
  # The real check probes the host disk — fdesetup on macOS, lsblk on Linux —
  # so both probes are stubbed. The row pins how each verdict is parsed and
  # signalled, not whether this particular machine happens to be encrypted.
  fm_stub fdesetup "printf 'FileVault is On.\\n'"
  fm_stub lsblk "printf 'NAME FSTYPE\\nsda1 crypto_LUKS\\n'"
  test_start "fm_encrypt_check"
  fm_run encrypt-check
  fm_expect_rc 0
  test_start "fm_encrypt_check_reports_an_encrypted_verdict"
  fm_expect_out_matches 'FileVault +On|LUKS +encrypted block device detected'

  # The negative verdict must reach the caller as rc=1, not be swallowed.
  fm_stub fdesetup "printf 'FileVault is Off.\\n'"
  fm_stub lsblk "printf 'NAME FSTYPE\\nsda1 ext4\\n'"
  test_start "fm_encrypt_check_unencrypted"
  fm_run encrypt-check
  fm_expect_rc 1
  test_start "fm_encrypt_check_unencrypted_says_so"
  fm_expect_out_matches 'FileVault +appears to be off|LUKS +no crypto volume detected'
  rm -f "$FM_SANDBOX/bin/fdesetup" "$FM_SANDBOX/bin/lsblk"
}

test_fm_telemetry() {
  # Opt-in by design: without DOTFILES_TELEMETRY=1 the command must refuse
  # with rc=1 and say how to enable it, rather than disabling OS services
  # silently. The variable is cleared explicitly so a developer shell that
  # exports it cannot steer this row into the mutating path, and sudo is a
  # recording stub so the refusal is shown to happen before any OS call.
  fm_stub sudo "printf 'SUDO %s\\n' \"\$*\" >>'$FM_SANDBOX/telemetry-sudo.log'"
  rm -f "$FM_SANDBOX/telemetry-sudo.log"
  test_start "fm_telemetry"
  DOTFILES_TELEMETRY= fm_run telemetry
  fm_expect_rc 1
  test_start "fm_telemetry_is_opt_in"
  fm_expect_out "disabled by default"
  test_start "fm_telemetry_says_how_to_enable"
  fm_expect_out "DOTFILES_TELEMETRY=1"
  test_start "fm_telemetry_refuses_before_touching_the_os"
  if [[ -e "$FM_SANDBOX/telemetry-sudo.log" ]]; then
    fm_fail "refusal path called sudo: $(head -1 "$FM_SANDBOX/telemetry-sudo.log")"
  else
    fm_pass "no sudo call"
  fi
  fm_stub sudo 'exit 0'
}

test_fm_policy() {
  test_start "fm_policy"
  # Deps-only: this row checks the command is wired up and reports, not that
  # the workspace is clean. A full pass walks every tracked file and shellchecks
  # every tracked script (~85s), which does not fit a smoke test with a 120s
  # budget — it began failing on the macOS runners once the script stopped
  # treating a missing opa as fatal and started actually scanning.
  #
  # The scan itself is covered by test_enforce_policies_fires.sh, which plants
  # violations and asserts the specific check that catches each one.
  #
  # Only grep/find/git are fatal dependencies and every runner has them;
  # opa/gitleaks/shellcheck being absent is a WARN with the checks skipped,
  # and with DEPS_ONLY the scan that could fail never runs — so rc=0 is the
  # deterministic outcome. DOTFILES_POLICY_STRICT is cleared because it would
  # turn a skipped optional tool into a hard error on a developer shell.
  DOTFILES_POLICY_STRICT= DOTFILES_POLICY_DEPS_ONLY=1 fm_run policy
  fm_expect_rc 0
  test_start "fm_policy_runs_the_dependency_check"
  fm_expect_out "Dependency check complete"
  test_start "fm_policy_deps_only_skips_the_scan"
  fm_expect_out "no scan performed"
  test_start "fm_policy_reports_the_dependency_verdict"
  fm_expect_out "Dependencies checked"
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
