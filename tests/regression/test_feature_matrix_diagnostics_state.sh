#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
#
# Every row pins the exact exit code the sandbox produces and asserts on
# output or files the command must produce. The two rows that time an
# interactive zsh (benchmark, load-bench) skip — with a message, not a widened
# code — when the runner has no zsh, which is the one host fact these
# commands cannot work without.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# fm_expect_attest_rc — workstation-attestation.sh needs jq and refuses
# before doing anything else without it. Both outcomes are exact contracts:
# rc=0 with jq, rc=1 plus the message without. The runner's toolbox decides
# which one applies, not the command.
fm_expect_attest_rc() {
  if command -v jq >/dev/null 2>&1; then
    fm_expect_rc 0
  else
    fm_expect_rc 1
    fm_expect_err "jq is required"
  fi
}

# fm_expect_file_under <dir> <name> — assert a file called <name> exists
# somewhere below <dir>.
fm_expect_file_under() {
  if find "$1" -type f -name "$2" 2>/dev/null | grep -q .; then
    fm_pass "$2 under $1"
  else
    fm_fail "no $2 under $1"
  fi
}

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
  fm_expect_attest_rc
  test_start "fm_attest_reports"
  fm_expect_out "--- Workstation Attestation ---"
  test_start "fm_attest_reports_version"
  fm_expect_out_matches 'Version +[0-9]+\.[0-9]+\.[0-9]+'
  test_start "fm_attest_writes_default_attestation"
  fm_expect_file "$XDG_STATE_HOME/dotfiles/attestations/workstation-attestation.json"
}

test_fm_attest_json() {
  test_start "fm_attest_json"
  fm_run attest --json
  fm_expect_attest_rc
  test_start "fm_attest_json_is_json"
  fm_expect_json
  test_start "fm_attest_json_has_platform"
  fm_expect_out '"platform"'
  test_start "fm_attest_json_has_version"
  fm_expect_out '"dotfiles_version"'
}

test_fm_attest_write() {
  # --write takes a path. A bare `dot attest -w` is a different thing: the
  # option parser runs `shift 2` on a single remaining argument, which under
  # set -e ends the script with rc=1 and no output at all. That is a CLI bug
  # to fix in the parser, not a contract to pin here.
  local out="$FM_SANDBOX/work/attest-write.json"
  test_start "fm_attest_write"
  fm_run attest -w "$out"
  fm_expect_attest_rc
  test_start "fm_attest_write_reports_the_path"
  fm_expect_out "$out"
  test_start "fm_attest_write_lands_at_the_path"
  fm_expect_file "$out"
  test_start "fm_attest_write_is_a_json_document"
  if [[ "$(head -c 1 "$out" 2>/dev/null)" == "{" ]]; then
    fm_pass "starts a JSON object"
  else
    fm_fail "$out does not start a JSON object"
  fi
  test_start "fm_attest_write_no_breakage"
  fm_expect_no_forbidden
}

test_fm_attest_fleet_store() {
  local store="$FM_SANDBOX/work/fleetstore"
  test_start "fm_attest_fleet_store"
  fm_run attest -F "$store" -I fmnode
  fm_expect_attest_rc
  test_start "fm_attest_fleet_store_reports_the_store"
  fm_expect_out "$store/fmnode/"
  test_start "fm_attest_fleet_store_writes_under_the_id"
  fm_expect_file "$store/fmnode"
  test_start "fm_attest_fleet_store_writes_the_attestation"
  fm_expect_file_under "$store/fmnode" "workstation-attestation.json"
}

test_fm_attestation() {
  test_start "fm_attestation"
  fm_run attestation
  fm_expect_attest_rc
  test_start "fm_attestation_is_alias_of_attest"
  fm_expect_out "--- Workstation Attestation ---"
  test_start "fm_attestation_reports_version"
  fm_expect_out_matches 'Version +[0-9]+\.[0-9]+\.[0-9]+'
}

# ── rollback ───────────────────────────────────────────────────────────────

test_fm_rollback_status() {
  test_start "fm_rollback_status"
  fm_run rollback status
  fm_expect_rc 0
  test_start "fm_rollback_status_reports"
  fm_expect_out "== Dotfiles Rollback Status =="
  test_start "fm_rollback_status_reports_chezmoi"
  fm_expect_out "Chezmoi:"
  test_start "fm_rollback_status_lists_backups"
  fm_expect_out "== Available Backups =="
}

test_fm_rollback_backup() {
  test_start "fm_rollback_backup"
  fm_run rollback backup
  fm_expect_rc 0
  test_start "fm_rollback_backup_creates_a_backup"
  fm_expect_out_matches 'Backup created: .*/backup_[0-9]{8}_[0-9]{6}_manual'
  test_start "fm_rollback_backup_lands_under_xdg_data_home"
  if find "$XDG_DATA_HOME/dotfiles/backups" -maxdepth 1 -type d -name 'backup_*_manual' 2>/dev/null | grep -q .; then
    fm_pass "backup directory written"
  else
    fm_fail "no backup_*_manual under $XDG_DATA_HOME/dotfiles/backups"
  fi
}

test_fm_rollback_clean() {
  test_start "fm_rollback_clean"
  fm_run rollback clean
  fm_expect_rc 0
  test_start "fm_rollback_clean_reports"
  fm_expect_out_matches 'Cleaning old backups \(keeping last [0-9]+\)'
  test_start "fm_rollback_clean_completes"
  fm_expect_out "Cleanup complete"
}

test_fm_rollback_unknown() {
  test_start "fm_rollback_unknown"
  fm_run rollback zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_rollback_unknown_prints_usage"
  fm_expect_any "Unknown command" "Usage"
}

# Content of <file> inside the Nth newest backup (1-based), as rollback-to
# numbers them.
fm_backup_content() {
  local n="$1" file="$2" dir
  dir="$(find "$XDG_DATA_HOME/dotfiles/backups" -maxdepth 1 -type d -name 'backup_*' | sort -r | sed -n "${n}p")"
  cat "$dir/$file" 2>/dev/null
}

test_fm_rollback_restore_paths() {
  # `rollback rollback` / `rollback-to N` / `restore FILE` rewrite $HOME from
  # a backup. $HOME is the sandbox here, so the real paths run for real.
  printf 'v1\n' >"$HOME/.bashrc"
  fm_run rollback backup
  test_start "fm_rollback_restore_paths_backup"
  fm_expect_rc 0

  printf 'v2\n' >"$HOME/.bashrc"
  test_start "fm_rollback_rollback_force"
  fm_run rollback rollback --force
  fm_expect_rc 0
  test_start "fm_rollback_rollback_restores_backup"
  if [[ "$(cat "$HOME/.bashrc")" == "v1" ]]; then fm_pass "restored v1"; else fm_fail "got $(cat "$HOME/.bashrc")"; fi

  printf 'v3\n' >"$HOME/.bashrc"
  local want
  want="$(fm_backup_content 1 .bashrc)"
  test_start "fm_rollback_rollback_to_index"
  fm_run rollback rollback-to 1 --force
  fm_expect_rc 0
  test_start "fm_rollback_rollback_to_restores_that_backup"
  if [[ -n "$want" && "$(cat "$HOME/.bashrc")" == "$want" ]]; then fm_pass "restored backup #1"; else fm_fail "got $(cat "$HOME/.bashrc"), want $want"; fi

  printf 'v4\n' >"$HOME/.bashrc"
  want="$(fm_backup_content 1 .bashrc)"
  test_start "fm_rollback_restore_file"
  fm_run rollback restore .bashrc
  fm_expect_rc 0
  test_start "fm_rollback_restore_file_content"
  if [[ "$(cat "$HOME/.bashrc")" == "$want" ]]; then fm_pass "file restored"; else fm_fail "got $(cat "$HOME/.bashrc"), want $want"; fi

  test_start "fm_rollback_restore_rejects_traversal"
  fm_run rollback restore ../../etc/passwd
  fm_expect_rc 1
}

test_fm_rollback_git_reset_keeps_work() {
  # git-reset runs against $HOME/.dotfiles, which the sandbox links to the
  # real checkout, so this case gets its own HOME and throwaway repository.
  local home="$FM_SANDBOX/rb-git-home" repo head
  repo="$home/.dotfiles"
  rm -rf "$home"
  mkdir -p "$repo"
  (
    cd "$repo" || exit 1
    git init -q -b main
    git config user.email fm@example.invalid
    git config user.name fm
    git config commit.gpgsign false
    git config tag.gpgsign false
    echo base >tracked.txt
    git add tracked.txt
    git commit -qm base
    git tag v1
    echo local >>tracked.txt
    git commit -qam local
    echo dirty >untracked.txt
  )
  head="$(git -C "$repo" rev-parse HEAD)"
  test_start "fm_rollback_git_reset_force"
  HOME="$home" fm_run rollback git-reset --force
  fm_expect_rc 0
  test_start "fm_rollback_git_reset_resets_to_tag"
  if [[ "$(git -C "$repo" rev-parse HEAD)" == "$(git -C "$repo" rev-parse 'v1^{commit}')" ]]; then fm_pass "HEAD at v1"; else fm_fail "HEAD not at v1"; fi
  test_start "fm_rollback_git_reset_keeps_old_head"
  if [[ "$(git -C "$repo" for-each-ref --format='%(objectname)' 'refs/heads/rollback-backup/*')" == "$head" ]]; then fm_pass "old HEAD kept on rollback-backup/*"; else fm_fail "no rollback-backup branch at the old HEAD"; fi
  test_start "fm_rollback_git_reset_stashes_untracked"
  if git -C "$repo" show --name-only --format= 'stash@{0}^3' 2>/dev/null | grep -qx untracked.txt; then fm_pass "untracked file stashed"; else fm_fail "untracked file not in the stash"; fi
}

# ── drift ──────────────────────────────────────────────────────────────────

test_fm_drift() {
  test_start "fm_drift"
  fm_run drift
  # The chezmoi shim reports no status and no source path, and the orphan
  # list lives under the sandboxed XDG_STATE_HOME, so every drift class is
  # empty and the dashboard exits 0.
  fm_expect_rc 0
  test_start "fm_drift_renders_dashboard"
  fm_expect_out "--- Dotfiles Drift Dashboard ---"
  test_start "fm_drift_finds_nothing_in_the_sandbox"
  fm_expect_out "no drift detected"
}

test_fm_drift_json() {
  test_start "fm_drift_json"
  fm_run drift --json
  fm_expect_rc 0
  test_start "fm_drift_json_is_json"
  fm_expect_json
  test_start "fm_drift_json_has_total"
  fm_expect_out '"total"'
  test_start "fm_drift_json_total_is_zero"
  fm_expect_out_matches '"total": *0[^0-9]*$'
}

# ── history ────────────────────────────────────────────────────────────────

test_fm_history() {
  printf ': 1700000000:0;ls\n: 1700000001:0;git status\n: 1700000002:0;ls\n' \
    >"$FM_SANDBOX/.zsh_history"
  test_start "fm_history"
  fm_run history
  fm_expect_rc 0
  test_start "fm_history_renders_analysis"
  fm_expect_out "--- History Analysis ---"
  test_start "fm_history_counts_commands"
  fm_expect_out_matches '^ +2 +ls$'
  test_start "fm_history_counts_by_base_command"
  fm_expect_out_matches '^ +1 +git$'
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
  # ~/.zsh_history still holds the `ls` rows from test_fm_history, so the
  # named file is only honoured if `ls` is absent from the analysis.
  local alt="$FM_SANDBOX/work/alt_history"
  printf ': 1700000000:0;kubectl\n: 1700000001:0;kubectl\n' >"$alt"
  test_start "fm_env_histfile"
  HISTFILE="$alt" fm_run history
  fm_expect_rc 0
  test_start "fm_env_histfile_analyses_the_named_file"
  fm_expect_out_matches '^ +2 +kubectl$'
  test_start "fm_env_histfile_ignores_the_default_file"
  if printf '%s\n' "$FM_OUT" | grep -Eq '^ +[0-9]+ +ls$'; then
    fm_fail "analysed ~/.zsh_history instead of \$HISTFILE"
  else
    fm_pass "no rows from ~/.zsh_history"
  fi
}

# ── benchmark / load-bench ─────────────────────────────────────────────────

test_fm_benchmark() {
  test_start "fm_benchmark"
  fm_run benchmark
  # benchmark.sh times `zsh -i -c exit` (through hyperfine when installed,
  # otherwise with its own loop). Without zsh there is nothing to time, so
  # the row skips — zsh is absent from the Linux CI runner.
  if ! command -v zsh >/dev/null 2>&1; then
    fm_pass "skipped — zsh not installed (benchmark times an interactive zsh)"
  else
    fm_expect_rc 0
  fi
  test_start "fm_benchmark_reports"
  fm_expect_out "--- Shell Performance Benchmark ---"
  test_start "fm_benchmark_reports_timings"
  if ! command -v zsh >/dev/null 2>&1; then
    fm_pass "skipped — zsh not installed"
  else
    fm_expect_out_matches 'Mean: +[0-9]+ms|Average startup time +[0-9]+ms'
  fi
}

test_fm_load_bench() {
  # `dot load-bench` execs the deployed dot-load-benchmark helper. In the
  # sandbox it is not on PATH, so shim it to the in-repo source rather than
  # skipping the row.
  fm_stub dot-load-benchmark \
    "exec bash '$REPO_ROOT/defaults/dot_local/bin/executable_dot-load-benchmark' \"\$@\""
  test_start "fm_load_bench"
  fm_run load-bench
  # The helper times zsh's heavy-layer readiness with `zsh -i -c`, so without
  # zsh on the host it prints its header and then exits 127. That is the
  # runner's toolbox, not a regression — the same environment-gap skip
  # test_dot_commands_execution.sh applies to a bare 127. zsh is the login
  # shell on the developer machines this was written on and is absent from
  # the Linux CI runner, which is exactly how this row first went red.
  if [[ "$FM_RC" -eq 127 ]] && ! command -v zsh >/dev/null 2>&1; then
    fm_pass "skipped — zsh not installed (load-bench times an interactive zsh)"
  else
    fm_expect_rc 0
  fi
  test_start "fm_load_bench_reports_header"
  fm_expect_out "dot load benchmark (runs=5)"
  test_start "fm_load_bench_reports_timings"
  if [[ "$FM_RC" -eq 127 ]] && ! command -v zsh >/dev/null 2>&1; then
    fm_pass "skipped — zsh not installed"
  else
    fm_expect_out_matches '^avg: [0-9]+(\.[0-9]+)? ms$'
  fi
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
  fm_expect_rc 1
  test_start "fm_chaos_refuses_without_force"
  fm_expect_out "WARNING"
  test_start "fm_chaos_names_the_force_flag"
  fm_expect_out "--force"
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
  # secret-governance.sh scans the checkout's git index, which the sandbox
  # does not stage into. It exits 1 only when a staged file matches a
  # plaintext-secret pattern — a real finding to act on, not host variance.
  fm_expect_rc 0
  test_start "fm_secret_audit_reports"
  fm_expect_out "Secret governance:"
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
  # Deterministic in the sandbox: the chezmoi shim prints nothing for
  # --version, so smoke-test.sh must flag it as "output mismatch" and exit
  # 1. That is the property worth pinning — the smoke test checks what a
  # tool says, not merely that it resolves.
  fm_expect_rc 1
  test_start "fm_smoke_test_reports"
  fm_expect_out "--- Dotfiles Smoke Tests ---"
  test_start "fm_smoke_test_flags_the_silent_chezmoi_shim"
  fm_expect_out_matches 'chezmoi +output mismatch'
  test_start "fm_smoke_test_summarises_failures"
  fm_expect_out_matches '[0-9]+ failed +[0-9]+ passed'
}

test_fm_intelligence() {
  test_start "fm_intelligence"
  fm_run intelligence
  fm_expect_rc 0
  test_start "fm_intelligence_renders_surface"
  fm_expect_out "D O T F I L E S"
  test_start "fm_intelligence_names_the_platform"
  fm_expect_out_matches 'Platform.*@ (macOS|Linux|WSL)'
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
  # --list exits 1 when the backup directory is missing altogether; create
  # it so the row does not depend on which earlier row happened to make it.
  mkdir -p "$XDG_DATA_HOME/dotfiles/backups"
  test_start "fm_restore_list"
  fm_run restore --list
  fm_expect_rc 0
  test_start "fm_restore_list_reports"
  fm_expect_out "--- Available Backups ---"
  test_start "fm_restore_list_shows_git_history"
  fm_expect_out "--- Git History (last 10) ---"
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
  # restore only recognises backup-* directories, and nothing in this suite
  # creates one (rollback writes backup_*), so it must fail cleanly rather
  # than restore something arbitrary.
  fm_expect_rc 1
  test_start "fm_restore_latest_handles_no_backups"
  fm_expect_out "No backups found"
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
  mkdir -p "$XDG_DATA_HOME/dotfiles/backups"
  test_start "fm_env_dotfiles_dir"
  DOTFILES_DIR="$repo" fm_run restore --list
  fm_expect_rc 0
  test_start "fm_env_dotfiles_dir_reads_that_checkout"
  fm_expect_out_matches '^[0-9a-f]{7,} add file$'
  test_start "fm_env_dotfiles_dir_reads_only_that_checkout"
  fm_expect_out_matches '^[0-9a-f]{7,} base$'
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
test_fm_rollback_restore_paths
test_fm_rollback_git_reset_keeps_work
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
