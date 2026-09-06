#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Dispatch and status tests for scripts/ops/rollback.sh.
#
# rollback.sh is a subcommand dispatcher over a backup directory. Every
# case below runs it against a private HOME whose ~/.dotfiles is a
# fixture git checkout and whose PATH holds only shims plus a sysbin of
# symlinked coreutils, so the backup listing, the chezmoi/git status
# probes and each dispatch arm are selected by the fixture rather than
# by whatever happens to be installed on the host.
#
# The mutating helpers (create_backup, perform_rollback, restore_file,
# git_reset, cleanup_old_backups) already carry LCOV_EXCL_START/STOP in
# the script; these tests drive the dispatcher arms that reach them,
# not their bodies.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

ROLLBACK_FILE="$REPO_ROOT/scripts/ops/rollback.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"

SYSBIN="$TMP/rb-sysbin"
mkdir -p "$SYSBIN"
for tool in awk sed grep tr find date stat wc head tail basename dirname \
  readlink realpath cut sort uniq cat cp mkdir rm touch ls env du printf sleep; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
# The fixture shims start with `#!/usr/bin/env bash`, so bash itself has
# to be resolvable from the restricted PATH.
ln -sf "$BASH" "$SYSBIN/bash"

R_BIN=""
R_HOME=""

_rb_scenario() {
  local name="$1"
  R_BIN="$TMP/rb-$name/bin"
  R_HOME="$TMP/rb-$name/home"
  mkdir -p "$R_BIN" "$R_HOME/.local/share" "$R_HOME/.local/state"
}

_rb_shim() {
  cat >"$R_BIN/$1"
  chmod +x "$R_BIN/$1"
}

# _rb_backups N: create N timestamped backup directories.
_rb_backups() {
  local n="$1" i
  mkdir -p "$R_HOME/.local/share/dotfiles/backups"
  for ((i = 1; i <= n; i++)); do
    local d="$R_HOME/.local/share/dotfiles/backups/backup_2026010${i}_120000_manual"
    mkdir -p "$d"
    printf 'timestamp=2026010%s_120000\nreason=manual\n' "$i" >"$d/.backup_meta"
    printf 'old zshrc %s\n' "$i" >"$d/.zshrc"
  done
}

# _rb_git_fixture: ~/.dotfiles as a directory containing a .git dir, so
# show_status takes its git branch.
_rb_git_fixture() {
  rm -f "$R_HOME/.dotfiles"
  mkdir -p "$R_HOME/.dotfiles/.git"
}

RB_OUT=""
RB_RC=0
RB_PATH_EXTRA=""
_run_rb() {
  RB_RC=0
  RB_OUT="$(
    cd "$R_HOME" &&
      env BASH_XTRACEFD=21 PATH="$R_BIN:$SYSBIN$RB_PATH_EXTRA" \
        HOME="$R_HOME" \
        XDG_DATA_HOME="$R_HOME/.local/share" \
        XDG_STATE_HOME="$R_HOME/.local/state" \
        XDG_RUNTIME_DIR="$R_HOME/run" \
        DOTFILES_ACCESSIBILITY=1 \
        "$BASH" "$ROLLBACK_FILE" "$@" </dev/null 2>&1 |
      sed -e 's/\x1b\[[0-9;]*m//g' -e 's/  */ /g'
    exit "${PIPESTATUS[0]}"
  )" || RB_RC=$?
}

_rb_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$RB_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $RB_RC"
  for needle in "$@"; do
    if [[ "$needle" == "NOT:"* ]]; then
      [[ "$RB_OUT" == *"${needle#NOT:}"* ]] &&
        problems="${problems}\n      unexpected: ${needle#NOT:}"
    else
      [[ "$RB_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
    fi
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$RB_OUT" | tail -40 | sed 's/^/      /'
  fi
}

# =======================================================================
# 1. help / usage
# =======================================================================
_rb_scenario help
mkdir -p "$R_HOME/run"
_run_rb help
_rb_expect "help_prints_usage" 0 \
  "Dotfiles Rollback & Recovery Tool" "rollback-to N" "restore FILE" \
  "-n, --dry-run" "rollback.sh status"

_run_rb --help
_rb_expect "help_flag_prints_usage" 0 "Dotfiles Rollback & Recovery Tool"

# =======================================================================
# 2. status with no backup directory at all
# =======================================================================
_rb_scenario nobackupdir
mkdir -p "$R_HOME/run"
_run_rb status
_rb_expect "status_without_backup_dir" 0 "Dotfiles Rollback Status" "No backups found"

# =======================================================================
# 3. status: chezmoi in sync, clean git tree, two backups, rollback log
# =======================================================================
_rb_scenario clean
mkdir -p "$R_HOME/run" "$R_HOME/.local/state/dotfiles"
_rb_git_fixture
_rb_backups 2
_rb_shim chezmoi <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "chezmoi version 2.47.1" ;;
  status) : ;;
esac
exit 0
EOF
_rb_shim git <<'EOF'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "rev-parse --short") echo "abc1234" ;;
  "branch --show-current") echo "main" ;;
  "status --porcelain") : ;;
esac
exit 0
EOF
printf '[2026-01-01T00:00:00] BACKUP_CREATED: backup_20260101_120000_manual\n' \
  >"$R_HOME/.local/state/dotfiles/rollback.log"
_run_rb status
_rb_expect "status_clean_tree_with_backups" 0 \
  "Chezmoi version: chezmoi version 2.47.1" "Chezmoi: All files in sync" \
  "Git commit: abc1234" "Git branch: main" "Git: Working tree clean" \
  "Available Backups" "backup_20260101_120000_manual" \
  "backup_20260102_120000_manual" \
  "Recent rollback activity:" "BACKUP_CREATED"

# =======================================================================
# 4. status: chezmoi drifted + dirty git tree (the other arms)
# =======================================================================
_rb_scenario drifted
mkdir -p "$R_HOME/run"
_rb_git_fixture
_rb_shim chezmoi <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "chezmoi version 2.47.1" ;;
  status) printf '%s\n' " M .zshrc" " M .bashrc" ;;
esac
exit 0
EOF
_rb_shim git <<'EOF'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "rev-parse --short") echo "def5678" ;;
  "branch --show-current") echo "feature" ;;
  "status --porcelain") printf '%s\n' " M a" " M b" " M c" ;;
esac
exit 0
EOF
mkdir -p "$R_HOME/.local/share/dotfiles/backups"
_run_rb status
_rb_expect "status_drifted_and_dirty" 0 \
  "Chezmoi: 2 file(s) out of sync" "Git branch: feature" \
  "Git: 3 uncommitted change(s)" "No backups found"

# =======================================================================
# 5. rollback with nothing to roll back to
# =======================================================================
_rb_scenario norollback
mkdir -p "$R_HOME/run"
_run_rb rollback
_rb_expect "rollback_without_backups_fails" 1 "No backups available for rollback"

# =======================================================================
# 6. rollback --dry-run resolves the latest backup
# =======================================================================
_rb_scenario latest
mkdir -p "$R_HOME/run"
_rb_backups 3
_run_rb rollback --dry-run
_rb_expect "rollback_dry_run_uses_latest_backup" 0 \
  "Rollback from: backup_20260103_120000_manual" "[DRY-RUN] Would restore: .zshrc"

# `read` sees EOF on a non-tty stdin, so the confirmation defaults to
# "no": the script must exit 0 without touching anything.
_run_rb rollback
_rb_expect "rollback_declined_at_prompt_exits_0" 0 "NOT:Rollback from:"

# =======================================================================
# 7. rollback-to argument validation and index lookup
# =======================================================================
_run_rb rollback-to
_rb_expect "rollback_to_without_index_fails" 1 "Please specify a backup number"

_run_rb rollback-to not-a-number
_rb_expect "rollback_to_non_numeric_fails" 1 "Please specify a backup number"

_run_rb rollback-to 99
_rb_expect "rollback_to_missing_index_fails" 1 "Backup #99 not found"

# Global options are parsed before the positional index, so --dry-run
# has to precede it.
_run_rb rollback-to --dry-run 2
_rb_expect "rollback_to_index_resolves_backup" 0 \
  "Rollback from: backup_20260102_120000_manual" "[DRY-RUN] Would restore: .zshrc"

_run_rb rollback-to 1
_rb_expect "rollback_to_declined_at_prompt_exits_0" 0 "NOT:Rollback from:"

# =======================================================================
# 8. restore / git-reset / clean / unknown, plus flag parsing
# =======================================================================
_run_rb restore
_rb_expect "restore_without_file_fails" 1 "Please specify a file to restore"

_run_rb git-reset
_rb_expect "git_reset_declined_at_prompt_exits_0" 0 "NOT:Git Reset"

_run_rb clean --force --verbose
_rb_expect "clean_reports_completion" 0 \
  "Cleaning old backups (keeping last 10)" "Cleanup complete"

_run_rb definitely-not-a-command
_rb_expect "unknown_command_fails_with_usage" 1 \
  "Unknown command: definitely-not-a-command" "Dotfiles Rollback & Recovery Tool"

_run_rb status -v -f -n
_rb_expect "global_flags_parse_before_dispatch" 0 "Dotfiles Rollback Status"

# =======================================================================
# 8b. Mutating dispatch arms, run against the disposable sandbox HOME.
# =======================================================================
_rb_scenario mutate
mkdir -p "$R_HOME/run" "$R_HOME/.config/shell"
_rb_git_fixture
printf 'export A=1\n' >"$R_HOME/.zshrc"
printf 'export B=2\n' >"$R_HOME/.config/shell/env.sh"
_rb_shim chezmoi <<'EOF'
#!/usr/bin/env bash
echo "chezmoi version 2.47.1"
exit 0
EOF
_rb_shim git <<'EOF'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "rev-parse --short") echo "abc1234" ;;
  "log --oneline") printf '%s\n' "abc1234 latest" "0000000 older" ;;
  "status --porcelain") : ;;
  "describe --tags") echo "v0.2.501" ;;
  "diff --stat") echo " README.md | 2 +-" ;;
esac
exit 0
EOF
_run_rb backup
_rb_expect "backup_creates_and_records_a_snapshot" 0 "Creating Backup: backup_" "Backup created:" "items)"
test_start "backup_wrote_a_backup_directory"
_snapshot="$(find "$R_HOME/.local/share/dotfiles/backups" -maxdepth 1 -type d -name 'backup_*' | head -1)"
if [[ -n "$_snapshot" && -f "$_snapshot/.backup_meta" && -f "$_snapshot/.zshrc" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no populated backup directory"
fi

# A forced rollback restores from that snapshot and appends to the log.
printf 'clobbered\n' >"$R_HOME/.zshrc"
_run_rb rollback --force
_rb_expect "forced_rollback_restores_and_logs" 0 "Rollback complete:" "file(s) restored"
test_start "forced_rollback_wrote_persist_log"
assert_file_contains "$R_HOME/.local/state/dotfiles/rollback.log" "ROLLBACK: from backup_" "rollback must append a ROLLBACK entry to the persistent log"

_run_rb restore .zshrc
_rb_expect "restore_file_dispatches" 0 "Restored: .zshrc"

_run_rb restore ../../etc/passwd
_rb_expect "restore_rejects_path_traversal" 1 "Path traversal detected"

_run_rb git-reset --dry-run
_rb_expect "git_reset_dispatches_in_dry_run" 0 \
  "Git Reset Recovery" "Reset target: v0.2.501" "[DRY-RUN] Would reset to: v0.2.501"

# `--help` after a command reaches the option parser's help arm.
_run_rb status --help
_rb_expect "help_flag_after_command_prints_usage" 0 "Dotfiles Rollback & Recovery Tool" "NOT:Dotfiles Rollback Status"

# =======================================================================
# 8c. flock concurrency guard: acquired, then already held.
# =======================================================================
_rb_scenario lock
mkdir -p "$R_HOME/run"
_rb_shim flock <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
_run_rb status
_rb_expect "flock_acquired_proceeds" 0 "Dotfiles Rollback Status"

_rb_shim flock <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_run_rb status
_rb_expect "flock_held_by_another_instance_exits_0" 0 "Already running" "NOT:Dotfiles Rollback Status"

# =======================================================================
# 9. ~/.dotfiles resolution fallbacks: readlink-only, then neither tool.
# =======================================================================
_rb_scenario resolve
mkdir -p "$R_HOME/run" "$R_HOME/.local/share/dotfiles/backups"
NOREAL="$TMP/rb-noreal"
mkdir -p "$NOREAL"
for f in "$SYSBIN"/*; do
  [[ "$(basename "$f")" == "realpath" ]] && continue
  ln -sf "$(readlink "$f")" "$NOREAL/$(basename "$f")"
done
NOEITHER="$TMP/rb-noeither"
mkdir -p "$NOEITHER"
for f in "$NOREAL"/*; do
  [[ "$(basename "$f")" == "readlink" ]] && continue
  ln -sf "$(readlink "$f")" "$NOEITHER/$(basename "$f")"
done

SYSBIN_SAVED="$SYSBIN"
SYSBIN="$NOREAL"
_run_rb status
SYSBIN="$SYSBIN_SAVED"
_rb_expect "resolves_dotfiles_source_via_readlink" 0 "Dotfiles Rollback Status"

SYSBIN="$NOEITHER"
_run_rb status
SYSBIN="$SYSBIN_SAVED"
_rb_expect "resolves_dotfiles_source_without_either_tool" 0 "Dotfiles Rollback Status"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
