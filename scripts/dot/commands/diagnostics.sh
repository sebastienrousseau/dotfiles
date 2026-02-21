#!/usr/bin/env bash
# Dotfiles CLI - Diagnostics Commands
# doctor, heal, health, rollback, drift, history, benchmark, verify, perf, scorecard, conflicts, locks, snapshot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

dot_ui_command_banner "Diagnostics" "${1:-}"

cmd_doctor() {
  echo "Running Dotfiles Doctor..."
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/diagnostics/doctor.sh" ]; then
    exec bash "$src_dir/scripts/diagnostics/doctor.sh" "$@"
  fi
  exec chezmoi doctor "$@"
}

cmd_heal() {
  run_script "scripts/ops/heal.sh" "Heal script" "$@"
}

cmd_health() {
  run_script "scripts/diagnostics/health.sh" "Health dashboard" "$@"
}

cmd_security_score() {
  run_script "scripts/diagnostics/security-score.sh" "Security score" "$@"
}

cmd_scorecard() {
  run_script "scripts/diagnostics/scorecard.sh" "Scorecard" "$@"
}

cmd_perf() {
  run_script "scripts/diagnostics/perf.sh" "Performance profiling" "$@"
}

cmd_conflicts() {
  run_script "scripts/diagnostics/conflicts.sh" "Conflicts report" "$@"
}

cmd_locks() {
  run_script "scripts/diagnostics/version-locks.sh" "Version locks" "$@"
}

cmd_snapshot() {
  run_script "scripts/diagnostics/snapshot.sh" "Snapshot" "$@"
}

cmd_rollback() {
  run_script "scripts/ops/rollback.sh" "Rollback script" "$@"
}

cmd_drift() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/diagnostics/drift-dashboard.sh" ]; then
    exec bash "$src_dir/scripts/diagnostics/drift-dashboard.sh" "$@"
  fi
  exec chezmoi status "$@"
}

cmd_history() {
  run_script "scripts/diagnostics/history-analysis.sh" "History analysis script" "$@"
}

cmd_benchmark() {
  run_script "scripts/diagnostics/benchmark.sh" "Benchmark script" "$@"
}

cmd_verify() {
  run_script "scripts/diagnostics/verify.sh" "Verify script" "$@"
}

cmd_restore() {
  run_script "scripts/dot/commands/restore.sh" "Restore script" "$@"
}

# Dispatch
case "${1:-}" in
  doctor)
    shift
    cmd_doctor "$@"
    ;;
  heal)
    shift
    cmd_heal "$@"
    ;;
  health | health-check)
    shift
    cmd_health "$@"
    ;;
  security-score)
    shift
    cmd_security_score "$@"
    ;;
  scorecard)
    shift
    cmd_scorecard "$@"
    ;;
  perf)
    shift
    cmd_perf "$@"
    ;;
  conflicts)
    shift
    cmd_conflicts "$@"
    ;;
  locks)
    shift
    cmd_locks "$@"
    ;;
  snapshot)
    shift
    cmd_snapshot "$@"
    ;;
  rollback)
    shift
    cmd_rollback "$@"
    ;;
  drift)
    shift
    cmd_drift "$@"
    ;;
  history)
    shift
    cmd_history "$@"
    ;;
  benchmark)
    shift
    cmd_benchmark "$@"
    ;;
  verify)
    shift
    cmd_verify "$@"
    ;;
  restore)
    shift
    cmd_restore "$@"
    ;;
  *)
    echo "Unknown diagnostics command: ${1:-}" >&2
    exit 1
    ;;
esac
