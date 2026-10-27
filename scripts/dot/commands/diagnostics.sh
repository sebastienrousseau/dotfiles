#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Diagnostics Commands
# verify, chaos, smoke-test (the doctor, config and shell commands are
# plugins)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Diagnostics" "${1:-}" "$@"

usage() {
  cat <<'EOF'
Usage: diagnostics.sh <command> [args...]

Commands:
  verify, chaos, smoke-test
EOF
}

cmd_smoke_test() {
  run_script "scripts/diagnostics/smoke-test.sh" "Smoke test script" "$@"
}

cmd_verify() {
  run_script "scripts/diagnostics/verify.sh" "Verify script" "$@"
}

cmd_chaos() {
  run_script "scripts/ops/chaos.sh" "Chaos engineering script" "$@"
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
  verify)
    shift
    cmd_verify "$@"
    ;;
  chaos)
    shift
    cmd_chaos "$@"
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
