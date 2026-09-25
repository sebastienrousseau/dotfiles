#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Behavioural tests for the three heal.sh component libraries:
#   scripts/ops/heal-chezmoi.sh  create_pre_heal_backup, heal_chezmoi_drift
#   scripts/ops/heal-system.sh   heal_broken_symlinks, heal_missing_critical_files,
#                                heal_missing_xdg_dirs
#   scripts/ops/heal-tools.sh    detect_pkg_manager, install_package,
#                                _mise_tool_specs, _install_with_mise, _do_install
#
# Each case sources the libraries the way heal.sh does (ui.sh, utils.sh, the
# shared counters and log helpers) in a clean environment whose PATH holds
# only core utilities plus recording stubs for chezmoi, mise, curl, sudo and
# the package managers. HOME is a mktemp sandbox; nothing is installed,
# applied or removed outside it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/heal-components.XXXXXX")" && pwd)"
trap 'rm -rf "$WORK"' EXIT
SANDBOX_HOME="$WORK/home"
TOOLS="$WORK/tools"
STUBS="$WORK/stubs"
CALLS="$WORK/calls"
OUT="$WORK/out"
FIXTURE_ROOT="$WORK/fixture-repo"
MANIFEST="$REPO_ROOT/security/remote-installers.sha256"

test_start "heal_components_exist"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-chezmoi.sh" "heal-chezmoi.sh exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-system.sh" "heal-system.sh exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-tools.sh" "heal-tools.sh exists"

# Core utilities only: host package managers, mise and chezmoi stay invisible.
mkdir -p "$TOOLS" "$STUBS"
for t in awk sed grep sort head tail tr cut mktemp mv cp cat date dirname basename \
  readlink rm mkdir rmdir ln chmod find wc id uname touch ls env sleep tput \
  sha256sum shasum perl; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" && "$p" == /* ]] && ln -s "$p" "$TOOLS/$t"
done
ln -s "$REAL_BASH" "$TOOLS/bash"

# stub <name> [body] — a recording stub; the default body just exits 0.
stub() {
  local name="$1" body="${2:-exit 0}"
  printf '#!%s\nprintf "%%s %%s\\n" "%s" "$*" >>"%s"\n%s\n' \
    "$REAL_BASH" "$name" "$CALLS" "$body" >"$STUBS/$name"
  chmod +x "$STUBS/$name"
}
unstub_all() { rm -f "$STUBS"/*; }
calls() { cat "$CALLS" 2>/dev/null || true; }
refute_contains() { # <needle> <actual> <msg>
  if [[ "$2" != *"$1"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $3"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $3 (found '$1')"
  fi
}

# reset_home — an empty sandbox HOME with the three shell rc files.
reset_home() {
  rm -rf "$SANDBOX_HOME"
  mkdir -p "$SANDBOX_HOME/.config/shell" "$SANDBOX_HOME/.config/nvim" "$SANDBOX_HOME/.config/git"
  printf 'bashrc\n' >"$SANDBOX_HOME/.bashrc"
  printf 'zshrc\n' >"$SANDBOX_HOME/.zshrc"
  printf 'profile\n' >"$SANDBOX_HOME/.profile"
  : >"$CALLS"
}

# heal <snippet> — source the heal libraries with heal.sh's shared state, run
# the snippet, then print the counters. Output lands in $OUT; the snippet's
# exit status is returned.
heal() {
  command env -i HOME="$SANDBOX_HOME" PATH="$STUBS:$TOOLS" TERM=dumb NO_COLOR=1 \
    XDG_DATA_HOME="$SANDBOX_HOME/.local/share" XDG_STATE_HOME="$SANDBOX_HOME/.local/state" \
    DRY_RUN="${DRY_RUN:-0}" FORCE="${FORCE:-0}" DOTFILES_NONINTERACTIVE=1 LANG=C \
    FAKE_STATUS="${FAKE_STATUS:-}" FAKE_STATUS_AFTER="${FAKE_STATUS_AFTER:-}" \
    FAKE_APPLY_RC="${FAKE_APPLY_RC:-0}" WORK="$WORK" \
    "$REAL_BASH" -c '
      set -euo pipefail
      source "$1/lib/dot/ui.sh"
      source "$1/lib/dot/utils.sh"
      REPO_ROOT="$2"
      BACKUP_DIR="$HOME/.local/share/dotfiles/backups"
      HEAL_LOG="$HOME/.local/state/dotfiles/heal.log"
      FIXES_APPLIED=0 ISSUES_FOUND=0 CHEZMOI_APPLIED=0 MISSING_DEPS_FOUND=0
      log_info() { ui_info "$@"; }
      log_success() { ui_ok "$@"; }
      log_warn() { ui_warn "$@"; }
      log_error() { ui_err "$@"; }
      log_step() { ui_section "$*"; }
      log_dry() { printf "DRY: %s\n" "$*"; }
      persist_log() { mkdir -p "${HEAL_LOG%/*}"; printf "%s\n" "$*" >>"$HEAL_LOG"; }
      source "$1/scripts/ops/heal-tools.sh"
      source "$1/scripts/ops/heal-system.sh"
      source "$1/scripts/ops/heal-chezmoi.sh"
      rc=0
      eval "$3" || rc=$?
      printf "ISSUES=%s FIXES=%s\n" "$ISSUES_FOUND" "$FIXES_APPLIED"
      exit "$rc"
    ' _ "$REPO_ROOT" "$FIXTURE_ROOT" "$1" >"$OUT" 2>&1
}
output() { cat "$OUT"; }

# chezmoi: `status` prints $FAKE_STATUS on the first call and
# $FAKE_STATUS_AFTER afterwards; `apply` exits $FAKE_APPLY_RC and, when
# $HOME/.restore is present, restores .profile the way a real apply would.
chezmoi_body='case "$1" in
  status)
    if [[ -e "$WORK/status-seen" ]]; then
      [[ -n "$FAKE_STATUS_AFTER" ]] && printf "%s\n" "$FAKE_STATUS_AFTER"
    else
      : >"$WORK/status-seen"
      [[ -n "$FAKE_STATUS" ]] && printf "%s\n" "$FAKE_STATUS"
    fi ;;
  apply)
    [[ -e "$HOME/.restore" ]] && printf "profile\n" >"$HOME/.profile"
    exit "$FAKE_APPLY_RC" ;;
esac
exit 0'

# ===========================================================================
# heal-chezmoi.sh
# ===========================================================================
test_start "create_pre_heal_backup_copies_shell_configs_inline"
reset_home
rm -f "$SANDBOX_HOME/.profile"
mkdir -p "$FIXTURE_ROOT"
heal create_pre_heal_backup
assert_equals "0" "$?" "the inline backup succeeds"
backup="$(find "$SANDBOX_HOME/.local/share/dotfiles/backups" -maxdepth 1 -name 'backup_*_pre_heal' 2>/dev/null | head -1)"
assert_equals "bashrc" "$(cat "$backup/.bashrc" 2>/dev/null)" ".bashrc is backed up"
assert_equals "zshrc" "$(cat "$backup/.zshrc" 2>/dev/null)" ".zshrc is backed up"
assert_equals "no" "$([[ -e "$backup/.profile" ]] && echo yes || echo no)" "an absent file is skipped"
assert_contains "Backup created at $backup" "$(output)" "the backup path is reported"

test_start "create_pre_heal_backup_prefers_rollback"
reset_home
mkdir -p "$FIXTURE_ROOT/scripts/ops"
printf '#!/usr/bin/env bash\nprintf "rollback %%s\\n" "$*" >>"%s"\n' "$CALLS" >"$FIXTURE_ROOT/scripts/ops/rollback.sh"
heal create_pre_heal_backup
assert_equals "0" "$?" "the rollback-backed backup succeeds"
assert_contains "rollback backup --force" "$(calls)" "rollback.sh takes a forced backup"
assert_equals "" "$(find "$SANDBOX_HOME/.local/share/dotfiles/backups" -name '*_pre_heal' 2>/dev/null)" \
  "no inline backup is made alongside it"
rm -rf "$FIXTURE_ROOT/scripts"

test_start "heal_chezmoi_drift_reapplies_drifted_files"
reset_home
stub chezmoi "$chezmoi_body"
rm -f "$WORK/status-seen"
FAKE_STATUS=" M .zshrc" FAKE_STATUS_AFTER="" heal heal_chezmoi_drift
assert_equals "0" "$?" "drift repair succeeds"
assert_contains "chezmoi apply --force" "$(calls)" "drift is re-applied with --force"
assert_contains "1 file(s) synced" "$(output)" "the synced count is reported"
assert_contains "ISSUES=1 FIXES=1" "$(output)" "one issue found, one fix applied"
assert_contains "HEAL: chezmoi apply --force" "$(cat "$SANDBOX_HOME/.local/state/dotfiles/heal.log" 2>/dev/null)" \
  "the repair is logged"

test_start "heal_chezmoi_drift_reports_remaining_drift"
reset_home
rm -f "$WORK/status-seen"
FAKE_STATUS=$' M .zshrc\n M .bashrc' FAKE_STATUS_AFTER=" M .bashrc" heal heal_chezmoi_drift
assert_contains "1 applied, 1 still drifted" "$(output)" "drift left after apply is reported"

test_start "heal_chezmoi_drift_dry_run_applies_nothing"
reset_home
rm -f "$WORK/status-seen"
DRY_RUN=1 FAKE_STATUS=" M .zshrc" heal heal_chezmoi_drift
assert_equals "0" "$?" "dry-run succeeds"
assert_contains "DRY: run 'chezmoi apply --force' to re-sync (1 file(s))" "$(output)" "the dry-run describes the fix"
refute_contains "chezmoi apply" "$(calls)" "chezmoi apply is not run"

test_start "heal_chezmoi_drift_leaves_source_only_drift"
reset_home
rm -f "$WORK/status-seen"
FAKE_STATUS="M  .zshrc" heal heal_chezmoi_drift
assert_contains "modified in source only" "$(output)" "source-only drift is explained"
refute_contains "chezmoi apply" "$(calls)" "source-only drift is not applied"

test_start "heal_chezmoi_drift_reports_apply_failure"
reset_home
rm -f "$WORK/status-seen"
FAKE_STATUS=" M .zshrc" FAKE_APPLY_RC=1 heal heal_chezmoi_drift
assert_equals "1" "$?" "a failed apply fails the repair"
assert_contains "chezmoi re-apply" "$(output)" "the failed step is named"
assert_contains "ISSUES=1 FIXES=0" "$(output)" "no fix is counted"

test_start "heal_chezmoi_drift_clean_state"
reset_home
rm -f "$WORK/status-seen"
heal heal_chezmoi_drift
assert_contains "chezmoi state" "$(output)" "a clean state is reported"
assert_contains "ISSUES=0 FIXES=0" "$(output)" "a clean state is not an issue"
unstub_all

# ===========================================================================
# heal-system.sh
# ===========================================================================
test_start "heal_broken_symlinks_removes_only_broken_links"
reset_home
ln -s "$SANDBOX_HOME/nowhere" "$SANDBOX_HOME/dangling"
ln -s "$SANDBOX_HOME/.bashrc" "$SANDBOX_HOME/good"
ln -s "$SANDBOX_HOME/gone" "$SANDBOX_HOME/SingletonLock"
FORCE=1 heal heal_broken_symlinks
assert_equals "0" "$?" "symlink repair succeeds"
assert_equals "no" "$([[ -L "$SANDBOX_HOME/dangling" ]] && echo yes || echo no)" "the broken link is removed"
assert_equals "yes" "$([[ -L "$SANDBOX_HOME/good" ]] && echo yes || echo no)" "a valid link is kept"
assert_equals "yes" "$([[ -L "$SANDBOX_HOME/SingletonLock" ]] && echo yes || echo no)" "a browser lock link is skipped"
assert_contains "ISSUES=1 FIXES=1" "$(output)" "one broken link found and fixed"

test_start "heal_broken_symlinks_dry_run_keeps_links"
reset_home
ln -s "$SANDBOX_HOME/nowhere" "$SANDBOX_HOME/dangling"
DRY_RUN=1 heal heal_broken_symlinks
assert_equals "yes" "$([[ -L "$SANDBOX_HOME/dangling" ]] && echo yes || echo no)" "dry-run removes nothing"
assert_contains "DRY: remove broken symlink: $SANDBOX_HOME/dangling -> $SANDBOX_HOME/nowhere" "$(output)" \
  "dry-run names the link and its target"

test_start "heal_broken_symlinks_clean_home"
reset_home
heal heal_broken_symlinks
assert_contains "ISSUES=0 FIXES=0" "$(output)" "no broken links, nothing to do"

test_start "heal_missing_critical_files_regenerates_via_chezmoi"
reset_home
stub chezmoi "$chezmoi_body"
rm -f "$SANDBOX_HOME/.profile"
: >"$SANDBOX_HOME/.restore"
heal heal_missing_critical_files
assert_equals "0" "$?" "critical file repair succeeds"
assert_contains "chezmoi apply --force" "$(calls)" "missing configs are regenerated by chezmoi apply"
assert_equals "profile" "$(cat "$SANDBOX_HOME/.profile" 2>/dev/null)" ".profile is restored"
assert_contains "ISSUES=1 FIXES=1" "$(output)" "one missing file found and restored"

test_start "heal_missing_critical_files_all_present"
reset_home
heal heal_missing_critical_files
assert_contains "ISSUES=0 FIXES=0" "$(output)" "nothing is missing"
refute_contains "chezmoi" "$(calls)" "chezmoi is not invoked"

test_start "heal_missing_critical_files_dry_run"
reset_home
rm -f "$SANDBOX_HOME/.zshrc"
DRY_RUN=1 heal heal_missing_critical_files
assert_contains "DRY: regenerate missing files via chezmoi" "$(output)" "dry-run describes the fix"
refute_contains "chezmoi apply" "$(calls)" "dry-run applies nothing"
unstub_all

test_start "heal_missing_xdg_dirs_creates_them"
reset_home
rm -rf "$SANDBOX_HOME/.config/nvim" "$SANDBOX_HOME/.config/git"
heal heal_missing_xdg_dirs
assert_equals "0" "$?" "xdg repair succeeds"
assert_equals "yes yes" "$([[ -d "$SANDBOX_HOME/.config/nvim" ]] && echo yes) $([[ -d "$SANDBOX_HOME/.config/git" ]] && echo yes)" \
  "missing XDG directories are created"
assert_contains "ISSUES=2 FIXES=2" "$(output)" "two missing directories found and created"

test_start "heal_missing_xdg_dirs_dry_run"
reset_home
rm -rf "$SANDBOX_HOME/.config/shell"
DRY_RUN=1 heal heal_missing_xdg_dirs
assert_equals "no" "$([[ -d "$SANDBOX_HOME/.config/shell" ]] && echo yes || echo no)" "dry-run creates nothing"
assert_contains "DRY: create directory: $SANDBOX_HOME/.config/shell" "$(output)" "dry-run names the directory"

# ===========================================================================
# heal-tools.sh
# ===========================================================================
test_start "detect_pkg_manager_follows_priority"
reset_home
heal detect_pkg_manager
assert_equals "" "$(head -1 "$OUT")" "no package manager is detected on a bare PATH"
stub apt-get
heal detect_pkg_manager
assert_equals "apt" "$(head -1 "$OUT")" "apt-get means apt"
stub dnf
heal detect_pkg_manager
assert_equals "apt" "$(head -1 "$OUT")" "apt wins over dnf"
stub brew
heal detect_pkg_manager
assert_equals "brew" "$(head -1 "$OUT")" "brew wins over every Linux manager"
unstub_all
stub pacman
heal detect_pkg_manager
assert_equals "pacman" "$(head -1 "$OUT")" "pacman is detected"
unstub_all

test_start "install_package_uses_sudo_with_apt"
reset_home
stub apt-get
stub sudo
heal 'install_package "$(get_package_name rg)"'
assert_equals "0" "$?" "an apt install succeeds"
assert_contains "sudo apt-get install -y -qq ripgrep" "$(calls)" "rg is installed as ripgrep through sudo apt-get"

test_start "install_package_refuses_apt_without_sudo"
reset_home
rm -f "$STUBS/sudo"
heal 'install_package fzf'
assert_equals "1" "$?" "apt without sudo fails"
assert_contains "sudo not found" "$(output)" "the missing sudo is reported"
refute_contains "apt-get" "$(calls)" "apt-get is never run without sudo"
unstub_all

test_start "install_package_uses_brew_without_sudo"
reset_home
stub brew
heal 'install_package bat'
assert_equals "0" "$?" "a brew install succeeds"
assert_contains "brew install --quiet bat" "$(calls)" "brew installs the package"
unstub_all

test_start "install_package_without_a_manager"
reset_home
heal 'install_package bat'
assert_equals "1" "$?" "no package manager fails"
assert_contains "No supported package manager found" "$(output)" "the reason is reported"

test_start "heal_tools_mise_specs_are_exact"
reset_home
heal 'for tool in nushell pueue wasmtime sops yazi zellij; do _mise_tool_specs "$tool"; done'
specs="$(grep -v '^ISSUES=' "$OUT")"
assert_equals "7" "$(printf '%s\n' "$specs" | wc -l | tr -d ' ')" "six tools map to seven specs (pueue + pueued)"
assert_equals "" "$(grep -Ev '^[A-Za-z0-9:_/-]+@[0-9]+\.[0-9]+\.[0-9]+$' <<<"$specs")" \
  "every spec pins an exact semver"
heal '_mise_tool_specs ripgrep'
assert_equals "1" "$?" "an unmapped tool has no spec"

test_start "install_with_mise_pins_every_spec"
reset_home
stub mise
heal '_install_with_mise pueue'
assert_equals "0" "$?" "a mise install succeeds"
assert_contains "mise use --global --pin aqua:Nukesor/pueue/pueue@4.0.4" "$(calls)" "pueue is pinned"
assert_contains "mise use --global --pin aqua:Nukesor/pueue/pueued@4.0.4" "$(calls)" "pueued is pinned"
stub mise 'exit 1'
heal '_install_with_mise pueue'
assert_equals "1" "$?" "a mise failure is returned"
unstub_all
heal '_install_with_mise sops'
assert_equals "1" "$?" "no mise means no mise install"

test_start "heal_tools_has_no_direct_binary_downloads"
# Drive every dependency heal knows through _do_install with mise absent and
# a recording curl: each download must be a checksum-pinned installer URL,
# never a GitHub release asset, and a payload that fails the checksum must
# never run.
reset_home
stub apt-get
stub sudo
stub curl 'out=""; url=""
while [[ $# -gt 0 ]]; do
  case "$1" in -o) out="$2"; shift 2 ;; -A) shift 2 ;; https://*) url="$1"; shift ;; *) shift ;; esac
done
printf "%s\n" "$url" >>"$WORK/urls"
printf "#!/bin/sh\n: >\"%s\"\n" "$WORK/executed" >"$out"'
rm -f "$WORK/urls" "$WORK/executed"
heal 'for cmd in zsh chezmoi starship rg bat fzf zoxide atuin yazi zellij nushell pueue wasmtime sops age hyperfine; do
  _do_install "$cmd" apt >/dev/null 2>&1 || printf "failed %s\n" "$cmd"
done'
urls="$(cat "$WORK/urls" 2>/dev/null)"
assert_contains "https://starship.rs/install.sh" "$urls" "starship uses its installer script"
assert_contains "https://setup.atuin.sh" "$urls" "atuin uses its installer script"
unpinned=0
while IFS= read -r u; do
  [[ -z "$u" ]] && continue
  [[ "$(awk -v u="$u" '$2 == u' "$MANIFEST" | wc -l | tr -d ' ')" == "1" ]] || unpinned=$((unpinned + 1))
done <<<"$urls"
assert_equals "0" "$unpinned" "every download is pinned in security/remote-installers.sha256"
assert_equals "" "$(grep -E 'github\.com/.*/releases/.*/(download|latest)' <<<"$urls")" \
  "no tool is fetched as a GitHub release binary"
assert_equals "no" "$([[ -e "$WORK/executed" ]] && echo yes || echo no)" "an unverified installer never runs"
assert_contains "failed starship" "$(output)" "a tampered starship installer fails the install"
assert_contains "sudo apt-get install -y -qq sops" "$(calls)" "mise-mapped tools fall back to the package manager"
assert_contains "sudo apt-get install -y -qq ripgrep" "$(calls)" "the rest go through the package manager"
unstub_all

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
