#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPTS=(
  "scripts/security/firewall.sh"
  "scripts/security/telemetry-kill.sh"
  "scripts/security/dns-doh.sh"
  "scripts/security/lock-screen.sh"
  "scripts/security/usb-safety.sh"
)

for script in "${SCRIPTS[@]}"; do
  script_path="$REPO_ROOT/$script"
  basename="$(basename "$script" .sh)"

  test_start "dry_run_${basename}_has_flag"
  assert_file_contains "$script_path" "--dry-run" "$basename should support --dry-run"

  test_start "dry_run_${basename}_has_var"
  assert_file_contains "$script_path" "DRY_RUN=" "$basename should set DRY_RUN variable"

  test_start "dry_run_${basename}_has_run_cmd"
  assert_file_contains "$script_path" "_run_cmd" "$basename should use _run_cmd wrapper"

  test_start "dry_run_${basename}_syntax"
  assert_exit_code 0 "bash -n '$script_path'"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
