#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

hook_script="$REPO_ROOT/scripts/git-hooks/pre-push"

make_stub_repo() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/.git" "$dir/scripts/git-hooks" "$dir/scripts/qa" "$dir/bin"
  cp "$hook_script" "$dir/scripts/git-hooks/pre-push"

  cat >"$dir/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  rev-parse)
    printf '%s\n' "${STUB_REPO_ROOT:?}"
    ;;
  cat-file)
    exit 0
    ;;
  rev-list)
    printf '%s\n' "abc123"
    ;;
  verify-commit)
    exit "${STUB_VERIFY_EXIT:-0}"
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$dir/bin/git"

  cat >"$dir/scripts/qa/reliability-audit.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit "${STUB_AUDIT_EXIT:-0}"
EOF
  chmod +x "$dir/scripts/qa/reliability-audit.sh"

  printf '%s\n' "$dir"
}

test_start "git_hook_pre_push_blocks_on_audit_failure"
stub_repo="$(make_stub_repo)"
set +e
output="$(printf 'refs/heads/feat abc refs/remotes/origin/feat def\n' | PATH="$stub_repo/bin:$PATH" STUB_REPO_ROOT="$stub_repo" STUB_AUDIT_EXIT=1 bash "$stub_repo/scripts/git-hooks/pre-push" 2>&1)"
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: pre-push blocks when reliability audit fails"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: pre-push should fail when reliability audit fails"
  printf '%b\n' "    Output: $output"
fi
rm -rf "$stub_repo"

# A push that only deletes remote branches sends no commits, so there is
# nothing to audit; running the full audit there only invited flakes.
ZERO=0000000000000000000000000000000000000000
set +e       # a failed assertion must not end the file before RESULTS
run_hook() { # <stdin> -> exit code, audit stubbed to fail
  local repo
  repo="$(make_stub_repo)"
  printf '%s' "$1" | PATH="$repo/bin:$PATH" STUB_REPO_ROOT="$repo" STUB_AUDIT_EXIT=1 \
    bash "$repo/scripts/git-hooks/pre-push" >/dev/null 2>&1
  local ec=$?
  rm -rf "$repo"
  return "$ec"
}

test_start "git_hook_pre_push_deletion_only_skips_audit"
run_hook "(delete) $ZERO refs/heads/old def
(delete) $ZERO refs/heads/older fed
"
ec=$?
assert_equals 0 "$ec" "deleting remote branches does not run the audit"

test_start "git_hook_pre_push_mixed_push_still_audits"
run_hook "(delete) $ZERO refs/heads/old def
refs/heads/feat abc refs/heads/feat def
"
ec=$?
assert_equals 1 "$ec" "a push that also updates a branch is audited"

test_start "git_hook_pre_push_blocks_unsigned_commit"
repo="$(make_stub_repo)"
out="$(printf 'refs/heads/feat abc refs/heads/feat def\n' | PATH="$repo/bin:$PATH" STUB_REPO_ROOT="$repo" \
  STUB_VERIFY_EXIT=1 bash "$repo/scripts/git-hooks/pre-push" 2>&1)"
ec=$?
rm -rf "$repo"
assert_equals 1 "$ec" "an unsigned commit blocks the push"
assert_contains "Blocked: unsigned commit abc123" "$out" "the unsigned commit is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
