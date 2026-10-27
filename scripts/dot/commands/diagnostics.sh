#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Diagnostics Commands
# history, verify, chaos, bundle, smoke-test (the doctor commands are
# plugins/doctor)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Diagnostics" "${1:-}" "$@"

usage() {
  cat <<'EOF'
Usage: diagnostics.sh <command> [args...]

Commands:
  history, verify, chaos, bundle, smoke-test
EOF
}

cmd_smoke_test() {
  run_script "scripts/diagnostics/smoke-test.sh" "Smoke test script" "$@"
}

cmd_history() {
  run_script "scripts/diagnostics/history-analysis.sh" "History analysis script" "$@"
}

cmd_verify() {
  run_script "scripts/diagnostics/verify.sh" "Verify script" "$@"
}

cmd_chaos() {
  run_script "scripts/ops/chaos.sh" "Chaos engineering script" "$@"
}

cmd_bundle() {
  run_script "scripts/ops/bundle.sh" "Offline bundle script" "$@"
}

# Dispatch
case "${1:-}" in
  --help | -h | help)
    usage
    ;;
  "")
    usage
    exit 1
    ;;
  history)
    shift
    cmd_history "$@"
    ;;
  verify)
    shift
    cmd_verify "$@"
    ;;
  chaos)
    shift
    cmd_chaos "$@"
    ;;
  bundle)
    shift
    cmd_bundle "$@"
    ;;
  smoke-test)
    shift
    cmd_smoke_test "$@"
    ;;
  *)
    echo "Unknown diagnostics command: ${1:-}" >&2
    exit 1
    ;;
esac
