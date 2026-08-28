#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Batched smoke tests for the shallowly-tested diagnostics commands:
# intelligence and chaos. Both are thin wrappers around run_script;
# the interesting invariants are the same for each:
#   * cmd_<name> function is defined
#   * `  <name>)` dispatch case exists
#   * The target script under scripts/... exists
#   * `dot <name>` reaches the wrapper without hitting the Unknown-
#     command fall-through
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DIAG_SH="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

# Loop through the commands with their target script paths.
declare -A TARGETS=(
  [intelligence]="lib/dot/bento.sh"
  [chaos]="scripts/ops/chaos.sh"
)

for cmd in "${!TARGETS[@]}"; do
  target_rel="${TARGETS[$cmd]}"
  target_abs="$REPO_ROOT/$target_rel"

  test_start "diag_${cmd}_module_defines_cmd_function"
  grep -qE "^cmd_${cmd}\(\)" "$DIAG_SH" && _ok || _fail

  test_start "diag_${cmd}_module_has_dispatch_case"
  grep -qE "^  ${cmd}\)" "$DIAG_SH" && _ok || _fail

  test_start "diag_${cmd}_delegates_to_run_script"
  # cmd_intelligence and cmd_chaos both wrap run_script "$target"...
  awk -v fn="^cmd_${cmd}\\\\(\\\\)" '$0 ~ fn { in_fn=1; next } in_fn && /^}/ { exit } in_fn' "$DIAG_SH" | grep -q "run_script" \
    && _ok || _fail "wrapper does not call run_script"

  test_start "diag_${cmd}_target_script_exists"
  # Verify the referenced script file is actually in the tree — a
  # renamed script would silently break the delegation otherwise.
  if [[ -f "$target_abs" ]]; then
    _ok
  else
    _fail "target script missing at $target_rel"
  fi

  test_start "diag_${cmd}_dispatch_reaches_wrapper_not_unknown"
  # Actually run the module with the command as $1 and a synthetic
  # sentinel arg; we can't run the target script safely, but the
  # dispatch itself should route to cmd_<name> which will try to
  # `run_script` the target. If run_script fails (script missing),
  # the module exits non-zero — but crucially not with the
  # "Unknown diagnostics command" line.
  out="$(bash "$DIAG_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown diagnostics command"* ]]; then
    _ok
  else
    _fail "dispatch hit the Unknown-command fall-through for '$cmd'"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
