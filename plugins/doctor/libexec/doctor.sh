#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Doctor Commands (moved from diagnostics.sh and security.sh,
# P2.1). plugins/doctor/dot-doctor maps the ADR-020 spellings onto these.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

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

cmd_heal() {
  run_script "scripts/ops/heal.sh" "Heal script" "$@"
}

cmd_health() {
  run_script "scripts/diagnostics/health.sh" "Health dashboard" "$@"
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

cmd_benchmark() {
  run_script "scripts/diagnostics/benchmark.sh" "Benchmark script" "$@"
}

cmd_restore() {
  run_script "plugins/doctor/libexec/restore.sh" "Restore script" "$@"
}

cmd_load_bench() {
  command dot-load-benchmark "$@"
}

cmd_load_bench_pty() {
  command dot-load-benchmark-pty "$@"
}

cmd_metrics() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [[ -z "$src_dir" ]]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  # shellcheck source=../../../lib/dot/log.sh
  # shellcheck disable=SC1091
  source "$src_dir/lib/dot/log.sh"
  ui_header "Recent Metrics"
  echo ""
  dot_metrics_summary "${1:-20}"
}

cmd_backup() {
  run_script "scripts/security/backup.sh" "Backup script" "$@"
}

# Every subcommand is cmd_<name> (dashes become underscores); health-check
# and score are the old aliases of health and scorecard.
_DOCTOR_COMMANDS="doctor heal health scorecard perf conflicts snapshot rollback drift benchmark restore load-bench load-bench-pty metrics backup"

# doctor_main SUBCOMMAND ARGS... — run one subcommand, or refuse it.
doctor_main() {
  local sub="${1:-}"
  case "$sub" in
    health-check) sub=health ;;
    score) sub=scorecard ;;
  esac
  if [[ "$sub" =~ ^[a-z-]+$ && " $_DOCTOR_COMMANDS " == *" $sub "* ]]; then
    shift
    "cmd_${sub//-/_}" "$@"
  else
    echo "Unknown doctor command: ${1:-}" >&2
    exit 1
  fi
}

# Sourced (by tests), only the functions are defined.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${1:-}" == backup ]]; then
    dot_ui_command_banner "Security" backup
  else
    dot_ui_command_banner "Diagnostics" "${1:-}" "$@"
  fi
  doctor_main "$@"
fi
