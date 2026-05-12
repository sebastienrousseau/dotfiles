#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Regression test for the pre-push audit bypass semantics.
#
# Validates that:
#   1. The legacy DOTFILES_SKIP_PRE_PUSH_AUDIT=1 is now REJECTED with a clear
#      migration message (was opt-out; now hard error).
#   2. The new DOTFILES_ALLOW_UNSKIPPED_PUSH=1 is the only valid bypass.
#   3. Every bypass writes a line to the audit-bypass.log under XDG_STATE_HOME.
#
# Regression for: GH-871

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$SCRIPT_DIR/../../framework/assertions.sh"

HOOK="$REPO_ROOT/scripts/git-hooks/pre-push"

# -----------------------------------------------------------------------------
# Structural checks
# -----------------------------------------------------------------------------

test_start "hook_exists"
assert_file_exists "$HOOK" "pre-push hook should exist"

test_start "hook_executable"
[[ -x "$HOOK" ]] && assert_exit_code 0 "true" || assert_exit_code 0 "false  # hook is not executable"

test_start "hook_uses_pipefail"
assert_file_contains "$HOOK" "set -euo pipefail" "pre-push hook must enforce strict mode"

test_start "hook_rejects_legacy_var"
assert_file_contains "$HOOK" "DOTFILES_SKIP_PRE_PUSH_AUDIT" \
  "hook must reference the legacy variable so it can reject it"

test_start "hook_uses_new_var"
assert_file_contains "$HOOK" "DOTFILES_ALLOW_UNSKIPPED_PUSH" \
  "hook must check the new bypass variable"

test_start "hook_writes_audit_log"
assert_file_contains "$HOOK" "audit-bypass.log" \
  "hook must log every bypass to audit-bypass.log"

test_start "hook_uses_xdg_state"
assert_file_contains "$HOOK" "XDG_STATE_HOME" \
  "hook must respect XDG_STATE_HOME for the log location"

# -----------------------------------------------------------------------------
# Behavioural checks
# Build a synthetic git environment so we can run the hook end-to-end without
# polluting the real repo.
# -----------------------------------------------------------------------------

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

(
  cd "$tmpdir"
  git init -q
  git config user.name "test"
  git config user.email "test@example.com"
  git config commit.gpgsign false  # signing is tested elsewhere
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "initial"
  cp "$HOOK" .git/hooks/pre-push
  chmod +x .git/hooks/pre-push
)

# Synthetic input that the hook reads on stdin: <local_ref local_sha remote_ref remote_sha>
# All-zero local_sha makes step 1 (signed-commit verification) skip via the
# hook's own "nothing to verify" continue. We're testing steps 2+3 only;
# signed-commit verification is covered by other tests.
ZERO="0000000000000000000000000000000000000000"
STDIN_LINE="refs/heads/main $ZERO refs/heads/main $ZERO"

# Test 1: legacy var → must FAIL with migration message
test_start "legacy_var_rejected"
output=$(cd "$tmpdir" && \
  XDG_STATE_HOME="$tmpdir/.state" \
  DOTFILES_SKIP_PRE_PUSH_AUDIT=1 \
  bash .git/hooks/pre-push <<<"$STDIN_LINE" 2>&1 || true)
if echo "$output" | grep -q "DOTFILES_SKIP_PRE_PUSH_AUDIT is no longer honored"; then
  assert_exit_code 0 "true"
else
  echo "Expected migration message; got: $output" >&2
  assert_exit_code 0 "false"
fi

# Test 2: legacy var → must exit non-zero
test_start "legacy_var_exits_nonzero"
set +e
(cd "$tmpdir" && \
  XDG_STATE_HOME="$tmpdir/.state" \
  DOTFILES_SKIP_PRE_PUSH_AUDIT=1 \
  bash .git/hooks/pre-push <<<"$STDIN_LINE" >/dev/null 2>&1)
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # legacy var did not cause non-zero exit"
fi

# Test 3: new var → bypass succeeds AND logs to the bypass log
test_start "new_var_writes_log"
rm -rf "$tmpdir/.state"
(cd "$tmpdir" && \
  XDG_STATE_HOME="$tmpdir/.state" \
  DOTFILES_ALLOW_UNSKIPPED_PUSH=1 \
  DOTFILES_BYPASS_REASON="test fixture" \
  bash .git/hooks/pre-push <<<"$STDIN_LINE" >/dev/null 2>&1) || true
log="$tmpdir/.state/dotfiles/audit-bypass.log"
if [[ -s "$log" ]] && grep -q "reason=test fixture" "$log"; then
  assert_exit_code 0 "true"
else
  echo "Expected log entry at $log with reason=test fixture; got:" >&2
  [[ -f "$log" ]] && cat "$log" >&2 || echo "(log file not created)" >&2
  assert_exit_code 0 "false"
fi

# Test 4: new var without DOTFILES_BYPASS_REASON should still work and record a default reason
test_start "new_var_default_reason"
rm -rf "$tmpdir/.state"
(cd "$tmpdir" && \
  XDG_STATE_HOME="$tmpdir/.state" \
  DOTFILES_ALLOW_UNSKIPPED_PUSH=1 \
  bash .git/hooks/pre-push <<<"$STDIN_LINE" >/dev/null 2>&1) || true
if grep -q "reason=no reason given" "$tmpdir/.state/dotfiles/audit-bypass.log"; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # default reason not recorded"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
