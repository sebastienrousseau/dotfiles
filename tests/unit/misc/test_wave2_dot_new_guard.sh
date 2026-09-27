#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 2: dot new Python pre-flight guard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

echo "Testing Wave 2: dot new Python pre-flight guard..."

test_start "dot_cli_exists"
assert_file_exists "$DOT_CLI" "executable_dot should exist"

# Run `dot new` for real in a scratch cwd. The python-less case gets a PATH
# of symlinks to every system tool except python*, so the pre-flight sees
# no interpreter while everything else `dot` needs is still there.
NEW_TMP="$(mktemp -d)"
trap 'rm -rf "$NEW_TMP"' EXIT
mkdir -p "$NEW_TMP/nopy" "$NEW_TMP/work"
IFS=: read -ra _path_dirs <<<"$PATH"
for d in "${_path_dirs[@]}"; do
  [[ -d "$d" ]] || continue
  for exe in "$d"/*; do
    name="${exe##*/}"
    [[ "$name" == python* || -e "$NEW_TMP/nopy/$name" || ! -x "$exe" ]] && continue
    ln -s "$exe" "$NEW_TMP/nopy/$name" 2>/dev/null || true
  done
done

test_start "python_check_before_filesystem_ops"
(cd "$NEW_TMP/work" && PATH="$NEW_TMP/nopy" CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" new python demo >"$NEW_TMP/out" 2>&1) && rc=0 || rc=$?
assert_equals "1|no" "$([[ $rc -ne 0 ]] && echo 1 || echo 0)|$([[ -e "$NEW_TMP/work/demo" ]] && echo yes || echo no)" "without python, dot new fails before creating anything"

test_start "python_error_to_stderr"
assert_contains "python3 is required" "$(cat "$NEW_TMP/out")" "the missing interpreter is named"

test_start "dot_new_renders_the_project_name"
(cd "$NEW_TMP/work" && CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" new python demo >/dev/null 2>&1) || true
assert_equals "0|1" "$(grep -rl '__PROJECT_NAME__' "$NEW_TMP/work/demo" 2>/dev/null | wc -l | tr -d ' ')|$([[ -d "$NEW_TMP/work/demo" ]] && echo 1 || echo 0)" "the project exists with every placeholder replaced"

test_start "dot_new_no_args_usage"
set +e
output=$(CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" new 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage:"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot new with no args shows usage"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot new with no args should show usage (ec=$ec)"
fi

echo ""
echo "Wave 2 dot new Python guard tests completed."
print_summary
