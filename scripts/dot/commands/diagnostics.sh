#!/usr/bin/env bash
# Dotfiles CLI - Diagnostics Commands
# doctor, heal, health, rollback, drift, history, benchmark

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../lib/ui.sh"

cmd_doctor() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/diagnostics/doctor.sh" ]; then
    exec bash "$src_dir/scripts/diagnostics/doctor.sh" "$@"
  fi
  ui_logo_dot "Dot Doctor • System Diagnostics"
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

cmd_rollback() {
  run_script "scripts/ops/rollback.sh" "Rollback script" "$@"
}

cmd_drift() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/diagnostics/drift-dashboard.sh" ]; then
    exec bash "$src_dir/scripts/diagnostics/drift-dashboard.sh" "$@"
  fi
  ui_logo_dot "Dot Drift • Dashboard"
  exec chezmoi status "$@"
}

cmd_history() {
  run_script "scripts/diagnostics/history-analysis.sh" "History analysis script" "$@"
}

cmd_benchmark() {
  run_script "scripts/diagnostics/benchmark.sh" "Benchmark script" "$@"
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
  restore)
    shift
    cmd_restore "$@"
    ;;
  *)
    ui_error "Unknown diagnostics command: ${1:-}"
    exit 1
    ;;
esac
