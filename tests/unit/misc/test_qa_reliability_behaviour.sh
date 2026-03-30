#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

audit_script="$REPO_ROOT/scripts/qa/reliability-audit.sh"

make_stub_repo() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/scripts/qa" "$dir/tests/framework" "$dir/examples"
  cp "$audit_script" "$dir/scripts/qa/reliability-audit.sh"

  cat >"$dir/tests/framework/test_runner.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'test_runner:%s\n' "$*" >>"${LOG_FILE:?}"
EOF
  chmod +x "$dir/tests/framework/test_runner.sh"

  cat >"$dir/tests/framework/module_coverage.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'module_coverage:%s\n' "${MIN_COVERAGE:-unset}" >>"${LOG_FILE:?}"
EOF
  chmod +x "$dir/tests/framework/module_coverage.sh"

  cat >"$dir/scripts/qa/validate-examples.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'validate_examples\n' >>"${LOG_FILE:?}"
EOF
  chmod +x "$dir/scripts/qa/validate-examples.sh"

  cat >"$dir/scripts/qa/docs-coverage.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'docs_coverage\n' >>"${LOG_FILE:?}"
EOF
  chmod +x "$dir/scripts/qa/docs-coverage.sh"

  cat >"$dir/scripts/qa/traceability-coverage.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'traceability_coverage\n' >>"${LOG_FILE:?}"
EOF
  chmod +x "$dir/scripts/qa/traceability-coverage.sh"

  printf '%s\n' "$dir"
}

test_start "qa_reliability_quick_skips_integration"
stub_repo="$(make_stub_repo)"
log_file="$stub_repo/run.log"
if LOG_FILE="$log_file" bash "$stub_repo/scripts/qa/reliability-audit.sh" --quick >/dev/null 2>&1; then
  if grep -q "test_runner:" "$log_file" && ! grep -q "test_runner:-i" "$log_file" && grep -q "docs_coverage" "$log_file" && grep -q "traceability_coverage" "$log_file"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: quick mode runs unit path with docs and traceability coverage"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: quick mode should skip integration runner and include docs plus traceability coverage"
  fi
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: quick mode exited non-zero"
fi
rm -rf "$stub_repo"

test_start "qa_reliability_with_integration_runs_integration"
stub_repo="$(make_stub_repo)"
log_file="$stub_repo/run.log"
if LOG_FILE="$log_file" bash "$stub_repo/scripts/qa/reliability-audit.sh" --with-integration >/dev/null 2>&1; then
  if grep -q "test_runner:-i" "$log_file" && grep -q "docs_coverage" "$log_file" && grep -q "traceability_coverage" "$log_file"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: integration flag runs integration suite with docs and traceability coverage"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: integration flag should run integration suite with docs and traceability coverage"
  fi
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: integration mode exited non-zero"
fi
rm -rf "$stub_repo"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
