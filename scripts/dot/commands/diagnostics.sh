#!/usr/bin/env bash
# Dotfiles CLI - Diagnostics Commands
# doctor, heal, health, rollback, drift, history, benchmark

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

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
  run_script "scripts/ops/health-check.sh" "Health check script" "$@"
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
  run_script "scripts/tests/benchmark.sh" "Benchmark script" "$@"
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
  *)
    echo "Unknown diagnostics command: ${1:-}" >&2
    exit 1
    ;;
esac
