#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# bin/dot routes agents, init and registry to their own modules. When a
# module is missing from the source dir (a partial checkout, a botched
# upgrade), the route must say which file is missing and exit 1, never 0.
# Runs a small copy of the CLI with those modules removed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup
COPY="$(fm_repo_copy "$FM_SANDBOX/partial")"
export CHEZMOI_SOURCE_DIR="$COPY"

for module in agents init registry; do
  rm -f "$COPY/scripts/dot/commands/$module.sh"
  test_start "missing_${module}_module_fails"
  fm_run_bin "$COPY/bin/dot" "$module"
  fm_expect_rc 1
  test_start "missing_${module}_module_is_named"
  if [[ "$FM_OUT$FM_ERR" == *"$module.sh not found"* ]]; then
    fm_pass "names $module.sh"
  else
    fm_fail "does not name the missing $module.sh: $FM_OUT$FM_ERR"
  fi
done

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
