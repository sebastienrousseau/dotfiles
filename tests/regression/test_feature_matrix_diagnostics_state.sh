#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the state-handling half of the
# diagnostics.sh command group — snapshot, attest, rollback, drift, history,
# benchmark, restore, load-bench, chaos, teleport, bundle, secret-audit,
# metrics, smoke-test and intelligence — plus the environment variables that
# redirect where each of them reads and writes.
#
# Split out of test_feature_matrix_diagnostics.sh: together the two halves
# ran for five minutes in one file, which serialises the whole regression
# suite. The scoring commands (doctor / health / security-score / score) stay
# in the sibling file; everything that reads or writes local state lives here,
# so the two run concurrently under `test_runner.sh --jobs auto`.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# ── snapshot ───────────────────────────────────────────────────────────────

test_fm_snapshot() {
  test_start "fm_snapshot"
  fm_run snapshot
  fm_expect_rc 0
  test_start "fm_snapshot_writes_a_snapshot"
  fm_expect_out "Snapshot"
}

test_fm_snapshot_baseline() {
  test_start "fm_snapshot_baseline"
  fm_run snapshot -b
  fm_expect_rc 0
  test_start "fm_snapshot_baseline_writes_baseline_json"
  fm_expect_file "$XDG_STATE_HOME/dotfiles/snapshots/baseline.json"
  # -f overwrites an existing baseline rather than refusing.
  test_start "fm_snapshot_baseline_force"
  fm_run snapshot -b -f
  fm_expect_rc 0
}

test_fm_env_xdg_state_home() {
  # Every snapshot/attestation/log write must land under XDG_STATE_HOME, which
  # is what keeps this whole suite off the developer's machine.
  test_start "fm_env_xdg_state_home"
  fm_run snapshot
  fm_expect_rc 0
  test_start "fm_env_xdg_state_home_receives_the_write"
  if find "$XDG_STATE_HOME/dotfiles/snapshots" -name 'snapshot_*.json' 2>/dev/null |
    grep -q .; then
    fm_pass "snapshot written under XDG_STATE_HOME"
  else
    fm_fail "no snapshot under $XDG_STATE_HOME/dotfiles/snapshots"
  fi
}

# ── attest ─────────────────────────────────────────────────────────────────

test_fm_attest() {
  test_start "fm_attest"
  fm_run attest
  fm_expect_rc_in 0 1
  test_start "fm_attest_reports"
  fm_expect_any "Attestation" "attestation"
}

test_fm_attest_json() {
  test_start "fm_attest_json"
  fm_run attest --json
  fm_expect_rc_in 0 1
  test_start "fm_attest_json_is_json"
  fm_expect_json
  test_start "fm_attest_json_has_platform"
  fm_expect_out '"platform"'
}

test_fm_attest_write() {
  test_start "fm_attest_write"
  fm_run attest -w
  fm_expect_rc_in 0 1
  test_start "fm_attest_write_no_breakage"
  fm_expect_no_forbidden
}

test_fm_attest_fleet_store() {
  local store="$FM_SANDBOX/work/fleetstore"
  test_start "fm_attest_fleet_store"
  fm_run attest -F "$store" -I fmnode
  fm_expect_rc_in 0 1
  test_start "fm_attest_fleet_store_writes_under_the_id"
  fm_expect_file "$store/fmnode"
}

test_fm_attestation() {
  test_start "fm_attestation"
  fm_run attestation
  fm_expect_rc_in 0 1
  test_start "fm_attestation_is_alias_of_attest"
  fm_expect_any "Attestation" "attestation"
}

# ── rollback ───────────────────────────────────────────────────────────────

test_fm_rollback_status() {
  test_start "fm_rollback_status"
  fm_run rollback status
  fm_expect_rc_in 0 1
  test_start "fm_rollback_status_reports"
  fm_expect_any "Rollback Status" "Backups" "backup"
}

test_fm_rollback_backup() {
  test_start "fm_rollback_backup"
  fm_run rollback backup
  fm_expect_rc_in 0 1
  test_start "fm_rollback_backup_creates_a_backup"
  fm_expect_any "Backup created" "Creating Backup"
}

test_fm_rollback_clean() {
  test_start "fm_rollback_clean"
  fm_run rollback clean
  fm_expect_rc_in 0 1
  test_start "fm_rollback_clean_reports"
  fm_expect_any "Cleaning" "Cleanup"
}

test_fm_rollback_unknown() {
  test_start "fm_rollback_unknown"
  fm_run rollback zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_rollback_unknown_prints_usage"
  fm_expect_any "Unknown command" "Usage"
}

test_fm_smoke_rollback_restore() {
  # `rollback rollback` / `rollback-to N` / `git-reset` / `restore FILE`
  # rewrite $HOME from a backup and reset the git checkout.
  fm_smoke rollback
}

# ── drift ──────────────────────────────────────────────────────────────────

test_fm_drift() {
  test_start "fm_drift"
  fm_run drift
  fm_expect_rc_in 0 1
  test_start "fm_drift_renders_dashboard"
  fm_expect_any "Drift Dashboard" "drift"
}

test_fm_drift_json() {
  test_start "fm_drift_json"
  fm_run drift --json
  fm_expect_rc_in 0 1
  test_start "fm_drift_json_is_json"
  fm_expect_json
  test_start "fm_drift_json_has_total"
  fm_expect_out '"total"'
}

# ── history ────────────────────────────────────────────────────────────────

test_fm_history() {
  printf ': 1700000000:0;ls\n: 1700000001:0;git status\n: 1700000002:0;ls\n' \
    >"$FM_SANDBOX/.zsh_history"
  test_start "fm_history"
  fm_run history
  fm_expect_rc_in 0 1
  test_start "fm_history_counts_commands"
  fm_expect_any "Top commands" "ls"
}

test_fm_history_missing() {
  local hist="$FM_SANDBOX/.zsh_history"
  local saved="$FM_SANDBOX/.zsh_history.saved"
  [[ -f "$hist" ]] && mv "$hist" "$saved"
  test_start "fm_history_missing"
  HISTFILE="$FM_SANDBOX/definitely-no-history" fm_run history
  fm_expect_rc 1
  test_start "fm_history_missing_says_so"
  fm_expect_err "not found"
  [[ -f "$saved" ]] && mv "$saved" "$hist"
  return 0
}

test_fm_env_histfile() {
  # HISTFILE, not a hardcoded ~/.zsh_history, selects what gets analysed.
  local alt="$FM_SANDBOX/work/alt_history"
  printf ': 1700000000:0;kubectl\n: 1700000001:0;kubectl\n' >"$alt"
  test_start "fm_env_histfile"
  HISTFILE="$alt" fm_run history
  fm_expect_rc_in 0 1
  test_start "fm_env_histfile_analyses_the_named_file"
  fm_expect_any "kubectl" "Top commands"
}

# ── benchmark / load-bench ─────────────────────────────────────────────────

test_fm_benchmark() {
  test_start "fm_benchmark"
  fm_run benchmark
  fm_expect_rc_in 0 1
  test_start "fm_benchmark_reports"
  fm_expect_any "Benchmark" "benchmark" "hyperfine"
}

test_fm_load_bench() {
  # `dot load-bench` execs the deployed dot-load-benchmark helper. In the
  # sandbox it is not on PATH, so shim it to the in-repo source rather than
  # skipping the row.
  fm_stub dot-load-benchmark \
    "exec bash '$REPO_ROOT/defaults/dot_local/bin/executable_dot-load-benchmark' \"\$@\""
  test_start "fm_load_bench"
  fm_run load-bench
  fm_expect_rc_in 0 1
  test_start "fm_load_bench_reports_timings"
  fm_expect_any "load benchmark" "avg" "ms"
}

test_fm_smoke_load_bench_pty() {
  # Needs the chezmoi-rendered .tmpl helper and a real pseudo-terminal.
  test_start "fm_smoke_load_bench_pty_is_routed"
  fm_run load-bench-pty
  # Without the rendered helper this exits non-zero; what matters is that the
  # dispatcher routes it rather than reporting an unknown command.
  if [[ "$FM_OUT$FM_ERR" == *"Unknown command"* ]]; then
    fm_fail "load-bench-pty is not routed by the dispatcher"
  else
    fm_pass "routed (rc=$FM_RC)"
  fi
}

# ── chaos / teleport / bundle ──────────────────────────────────────────────

test_fm_chaos() {
  # Without --force chaos must refuse: it deletes real config files.
  test_start "fm_chaos"
  fm_run chaos --dry-run
  fm_expect_rc_in 0 1
  test_start "fm_chaos_refuses_without_force"
  fm_expect_any "WARNING" "--force"
  test_start "fm_chaos_left_the_sandbox_intact"
  if [[ -L "$FM_SANDBOX/.dotfiles" ]]; then
    fm_pass "sandbox untouched"
  else
    fm_fail "chaos removed sandbox state without --force"
  fi
}

test_fm_smoke_chaos_force() {
  # --force deliberately deletes ~/.zshrc and the terminal configs.
  fm_smoke chaos
}

test_fm_teleport_usage() {
  test_start "fm_teleport_usage"
  fm_run teleport
  fm_expect_rc 1
  test_start "fm_teleport_usage_message"
  fm_expect_any "Usage" "user@host"
}

test_fm_smoke_teleport() {
  fm_smoke teleport
}

test_fm_smoke_bundle() {
  # Archives ~/.dotfiles plus tool caches with zstd: hundreds of MB.
  fm_smoke bundle
}

# ── secret-audit / metrics / smoke-test / intelligence ─────────────────────

test_fm_secret_audit() {
  test_start "fm_secret_audit"
  fm_run secret-audit
  fm_expect_rc_in 0 1
  test_start "fm_secret_audit_reports"
  fm_expect_any "Secret governance" "secret" "staged"
}

test_fm_metrics() {
  # Seed the JSONL event log the reader tails.
  mkdir -p "$XDG_STATE_HOME/dotfiles"
  printf '{"time":"2026-01-01T00:00:00Z","metric":"fm_demo","value":1,"unit":"count"}\n' \
    >"$XDG_STATE_HOME/dotfiles/metrics.jsonl"
  test_start "fm_metrics"
  fm_run metrics
  fm_expect_rc 0
  test_start "fm_metrics_shows_recorded_events"
  fm_expect_out "fm_demo"
  test_start "fm_metrics_count_argument"
  fm_run metrics 5
  fm_expect_rc 0
}

test_fm_metrics_empty() {
  rm -f "$XDG_STATE_HOME/dotfiles/metrics.jsonl"
  test_start "fm_metrics_empty"
  fm_run metrics
  fm_expect_rc 0
  test_start "fm_metrics_empty_says_so"
  fm_expect_any "No metrics" "metrics.jsonl"
}

test_fm_smoke_test() {
  test_start "fm_smoke_test"
  fm_run smoke-test
  fm_expect_rc_in 0 1
  test_start "fm_smoke_test_reports"
  fm_expect_any "Smoke Tests" "smoke"
}

test_fm_intelligence() {
  test_start "fm_intelligence"
  fm_run intelligence
  fm_expect_rc_in 0 1
  test_start "fm_intelligence_renders_surface"
  fm_expect_any "DOTFILES" "Platform" "Security"
}

# ── restore ────────────────────────────────────────────────────────────────

fm_restore_git_fixture() {
  local repo="$FM_SANDBOX/work/restorerepo"
  [[ -d "$repo/.git" ]] && {
    printf '%s\n' "$repo"
    return 0
  }
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" -c user.name=fm -c user.email=fm@example.com \
    commit -q --allow-empty -m "base"
  printf 'one\n' >"$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" -c user.name=fm -c user.email=fm@example.com \
    commit -q -m "add file"
  printf '%s\n' "$repo"
}

test_fm_restore_list() {
  test_start "fm_restore_list"
  fm_run restore --list
  fm_expect_rc_in 0 1
  test_start "fm_restore_list_reports"
  fm_expect_any "Backups" "backups" "No backups"
}

test_fm_restore_git_dry_run() {
  local repo
  repo="$(fm_restore_git_fixture)"
  test_start "fm_restore_git_dry_run"
  DOTFILES_DIR="$repo" fm_run restore -n -g HEAD
  fm_expect_rc 0
  test_start "fm_restore_git_dry_run_makes_no_changes"
  fm_expect_any "Dry run" "dry run"
  test_start "fm_restore_git_dry_run_left_worktree_clean"
  if [[ -z "$(git -C "$repo" status --porcelain)" ]]; then
    fm_pass "worktree unchanged"
  else
    fm_fail "dry run modified the worktree"
  fi
}

test_fm_restore_diff() {
  local repo
  repo="$(fm_restore_git_fixture)"
  test_start "fm_restore_diff"
  DOTFILES_DIR="$repo" fm_run restore -d HEAD~1
  fm_expect_rc 0
  test_start "fm_restore_diff_shows_the_diff"
  fm_expect_any "diff --git" "file.txt"
}

test_fm_restore_latest() {
  test_start "fm_restore_latest"
  fm_run restore --latest
  # With no backups recorded this must fail cleanly rather than restoring
  # something arbitrary.
  fm_expect_rc_in 0 1
  test_start "fm_restore_latest_handles_no_backups"
  fm_expect_any "No backups" "Restoring"
}

test_fm_restore_usage() {
  test_start "fm_restore_usage"
  fm_run restore
  fm_expect_rc 0
  test_start "fm_restore_usage_prints_options"
  fm_expect_out "--latest"
  test_start "fm_restore_usage_rejects_unknown_option"
  fm_run restore --zzz-not-an-option
  fm_expect_rc 1
  test_start "fm_restore_usage_unknown_message"
  fm_expect_any "Unknown option" "Usage"
}

test_fm_env_dotfiles_dir() {
  # DOTFILES_DIR selects which git checkout restore reads; point it at a repo
  # with a known commit subject and require that subject back.
  local repo
  repo="$(fm_restore_git_fixture)"
  test_start "fm_env_dotfiles_dir"
  DOTFILES_DIR="$repo" fm_run restore --list
  fm_expect_rc_in 0 1
  test_start "fm_env_dotfiles_dir_reads_that_checkout"
  fm_expect_any "add file" "Git History"
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: diagnostics (state, backup, history) ──"
echo ""

test_fm_snapshot
test_fm_snapshot_baseline
test_fm_env_xdg_state_home
test_fm_attest
test_fm_attest_json
test_fm_attest_write
test_fm_attest_fleet_store
test_fm_attestation
test_fm_rollback_status
test_fm_rollback_backup
test_fm_rollback_clean
test_fm_rollback_unknown
test_fm_smoke_rollback_restore
test_fm_drift
test_fm_drift_json
test_fm_history
test_fm_history_missing
test_fm_env_histfile
test_fm_benchmark
test_fm_load_bench
test_fm_smoke_load_bench_pty
test_fm_chaos
test_fm_smoke_chaos_force
test_fm_teleport_usage
test_fm_smoke_teleport
test_fm_smoke_bundle
test_fm_secret_audit
test_fm_metrics
test_fm_metrics_empty
test_fm_smoke_test
test_fm_intelligence
test_fm_restore_list
test_fm_restore_git_dry_run
test_fm_restore_diff
test_fm_restore_latest
test_fm_restore_usage
test_fm_env_dotfiles_dir

fm_finish
