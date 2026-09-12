#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Every place that turns `chezmoi status`/`verify` into a drift verdict must
# exclude the `always` entry type. defaults/run_before_macos-icloud-symlinks
# is pending on every apply by design, so without the flag a synchronised
# macOS machine reads as drifted forever (v0.2.520 regression).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "always_run_script_exists_so_the_guard_is_load_bearing"
assert_file_exists "$REPO_ROOT/defaults/run_before_macos-icloud-symlinks.sh.tmpl" \
  "the always-run hook this guard exists for is still in the tree"

# file|expected number of chezmoi status/verify calls|expected with --exclude=always
while IFS='|' read -r rel calls; do
  test_start "drift_caller_excludes_always_$(basename "$rel" .sh | tr -c 'a-z0-9\n' '_')"
  f="$REPO_ROOT/$rel"
  # Comment lines are not calls.
  total="$(grep -vE '^[[:space:]]*#' "$f" | grep -cE 'chezmoi (status|verify)\b' || true)"
  excl="$(grep -vE '^[[:space:]]*#' "$f" | grep -cE 'chezmoi (status|verify) --exclude=always\b' || true)"
  assert_equals "$calls" "$total" "$rel: expected $calls chezmoi status/verify call(s)"
  assert_equals "$total" "$excl" "$rel: every chezmoi status/verify call passes --exclude=always"
done <<'LIST'
scripts/diagnostics/doctor.sh|1
scripts/diagnostics/health.sh|1
scripts/diagnostics/scorecard.sh|1
scripts/diagnostics/drift-dashboard.sh|1
scripts/dot/commands/fleet.sh|2
LIST

print_summary
