#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Diagnostics Commands
# doctor, heal, health, rollback, drift, history, benchmark, verify, perf,
# scorecard, conflicts, locks, snapshot, load-bench, chaos, bundle, attest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

dot_ui_command_banner "Diagnostics" "${1:-}" "$@"

cmd_doctor() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  # Prefer the unified doctor script (doctor-unified.sh)
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/diagnostics/doctor-unified.sh" ]; then
    exec bash "$src_dir/scripts/diagnostics/doctor-unified.sh" "$@"
  elif [ -n "$src_dir" ] && [ -f "$src_dir/scripts/diagnostics/doctor.sh" ]; then
    exec bash "$src_dir/scripts/diagnostics/doctor.sh" "$@"
  fi
  exec chezmoi doctor "$@"
}

cmd_smoke_test() {
  run_script "scripts/diagnostics/smoke-test.sh" "Smoke test script" "$@"
}

cmd_intelligence() {
  run_script "scripts/dot/lib/bento.sh" "Intelligence Surface" "$@"
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

cmd_attest() {
  run_script "scripts/diagnostics/workstation-attestation.sh" "Workstation attestation" "$@"
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

cmd_load_bench() {
  command dot-load-benchmark "$@"
}

cmd_load_bench_pty() {
  command dot-load-benchmark-pty "$@"
}

cmd_chaos() {
  run_script "scripts/ops/chaos.sh" "Chaos engineering script" "$@"
}

cmd_bundle() {
  run_script "scripts/ops/bundle.sh" "Offline bundle script" "$@"
}

cmd_metrics() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [[ -z "$src_dir" ]]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  # shellcheck source=../lib/log.sh
  # shellcheck disable=SC1091
  source "$src_dir/scripts/dot/lib/log.sh"
  ui_header "Recent Metrics"
  echo ""
  dot_metrics_summary "${1:-20}"
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
  scorecard | score)
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
  attest | attestation)
    shift
    cmd_attest "$@"
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
  load-bench)
    shift
    cmd_load_bench "$@"
    ;;
  load-bench-pty)
    shift
    cmd_load_bench_pty "$@"
    ;;
  chaos)
    shift
    cmd_chaos "$@"
    ;;
  bundle)
    shift
    cmd_bundle "$@"
    ;;
  metrics)
    shift
    cmd_metrics "$@"
    ;;
  smoke-test)
    shift
    cmd_smoke_test "$@"
    ;;
  intelligence)
    shift
    cmd_intelligence "$@"
    ;;
  *)
    echo "Unknown diagnostics command: ${1:-}" >&2
    exit 1
    ;;
esac
