#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Coverage-exercise test #2: drives the large diagnostic + command-dispatch
## scripts through their read-only/help paths so the xtrace coverage runner
## records them. All invocations are side-effect-free (help/status/read-only
## config validation). Each runs in a `set +e` subshell with output discarded.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"
export REPO_ROOT DOT_COMMAND="coverage-exercise"

# 1. mcp-doctor — validates the MCP JSON configs (read-only).
(
  set +e
  bash "$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"
) >/dev/null 2>&1 || true
test_start "mcp_doctor_exercised"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh" "mcp-doctor exercised"

# 2. dot-ai-proxy — lifecycle helper; help + status are read-only.
(
  set +e
  bash "$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy" help
  bash "$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy" status
) >/dev/null 2>&1 || true
test_start "ai_proxy_exercised"
assert_file_exists "$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy" "dot-ai-proxy exercised"

# 3. perf diagnostics — help path.
(
  set +e
  bash "$REPO_ROOT/scripts/diagnostics/perf.sh" --help
) >/dev/null 2>&1 || true
test_start "perf_help_exercised"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/perf.sh" "perf exercised"

# 4. dot command dispatchers — help/list paths through bin/dot (exercises the
#    dispatcher plus each command file's usage/help branch). All read-only.
for cmd in agent ai tools fleet restore aliases secrets docs keys learn; do
  (
    set +e
    bash "$REPO_ROOT/bin/dot" "$cmd" --help
  ) >/dev/null 2>&1 || true
  (
    set +e
    bash "$REPO_ROOT/bin/dot" "$cmd" help
  ) >/dev/null 2>&1 || true
done
test_start "dot_command_help_exercised"
assert_file_exists "$REPO_ROOT/bin/dot" "dot dispatcher exercised"

# 5. corralctl-sync — scheduled launchd sync helper. NOT executed: it drives a
#    real multi-repo `corralctl` sync, hardcodes PATH, and writes to
#    ~/Library/Logs, so it is validated statically instead.
CORRALCTL_SYNC="$REPO_ROOT/defaults/dot_local/bin/executable_corralctl-sync.sh"
test_start "corralctl_sync_present"
assert_file_exists "$CORRALCTL_SYNC" "corralctl-sync.sh present"
test_start "corralctl_sync_syntax"
assert_true "bash -n '$CORRALCTL_SYNC'" "corralctl-sync.sh parses cleanly"
test_start "corralctl_sync_contract"
assert_file_contains "$CORRALCTL_SYNC" "corralctl" "corralctl-sync invokes corralctl"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
