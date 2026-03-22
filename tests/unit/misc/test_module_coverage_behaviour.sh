#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

coverage_script="$REPO_ROOT/tests/framework/module_coverage.sh"

make_stub_repo() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/scripts/alpha" "$dir/tests/unit" "$dir/tests/framework"
  cp "$coverage_script" "$dir/tests/framework/module_coverage.sh"

  cat >"$dir/scripts/alpha/tool.sh" <<'EOF'
#!/usr/bin/env bash
echo tool
EOF

  cat >"$dir/scripts/alpha/toolbox.sh" <<'EOF'
#!/usr/bin/env bash
echo toolbox
EOF

  cat >"$dir/tests/unit/test_toolbox.sh" <<'EOF'
#!/usr/bin/env bash
toolbox
alpha_toolbox
EOF

  printf '%s\n' "$dir"
}

test_start "module_coverage_rejects_overlap_false_positive"
stub_repo="$(make_stub_repo)"
set +e
output="$(REPO_ROOT="$stub_repo" TESTS_DIR="$stub_repo/tests" bash "$stub_repo/tests/framework/module_coverage.sh" 2>&1)"
ec=$?
set -e
if [[ "$ec" -ne 0 ]] && [[ "$output" == *"alpha/tool"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: overlap names do not count as coverage"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: overlap names should leave alpha/tool uncovered"
  printf '%b\n' "    Output: $output"
fi
rm -rf "$stub_repo"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
