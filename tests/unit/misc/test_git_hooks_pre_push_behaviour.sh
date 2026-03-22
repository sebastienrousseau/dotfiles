#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
    exit 0
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

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
