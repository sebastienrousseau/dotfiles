#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Unified doctor orchestrator — parses flags and dispatches to existing scripts.
set -euo pipefail

_cleanup_files=()
trap 'rm -f "${_cleanup_files[@]}"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
ui_init

passthrough=()
target="scripts/diagnostics/doctor.sh"

for arg in "$@"; do
  case "$arg" in
    --heal) target="scripts/ops/heal.sh" ;;
    --audit) target="scripts/ops/health-check.sh" ;;
    --score) target="scripts/diagnostics/scorecard.sh" ;;
    --smoke) target="scripts/diagnostics/smoke-test.sh" ;;
    --drift) target="scripts/diagnostics/drift-dashboard.sh" ;;
    --benchmark) target="tests/benchmark.sh" ;;
    --json | --ai) passthrough+=("$arg") ;;
    *) passthrough+=("$arg") ;;
  esac
done

script="$REPO_ROOT/$target"
if [[ ! -f "$script" ]]; then
  ui_err "Script not found" "$target"
  exit 1
fi

exec bash "$script" "${passthrough[@]+"${passthrough[@]}"}"
