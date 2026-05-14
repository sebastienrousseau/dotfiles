#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: compliance-guard must hard-fail on portability shellcheck
# findings (was silently soft-fail before #857).
#
# Regression for: GH-857
# Why: Without hard-fail, portability drift accumulated invisibly — the
# job ran, reported, and exited 0 regardless of findings.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck source=../framework/assertions.sh
source "$SCRIPT_DIR/../framework/assertions.sh"

WORKFLOW="$REPO_ROOT/.github/workflows/compliance-guard.yml"

# -----------------------------------------------------------------------------
# Structural: the workflow must hard-fail and stay at warning severity.
# -----------------------------------------------------------------------------

test_start "workflow_exists"
assert_file_exists "$WORKFLOW" "compliance-guard workflow should exist"

test_start "portability_invokes_shell_lint"
assert_file_contains "$WORKFLOW" "reusable-shell-lint.yml" \
  "portability check must invoke the reusable shell-lint workflow"

extract_portability_block() {
  # Capture lines from `portability-shell-lint:` until the next sibling job
  # (a line at the same indent that ends in `:` and isn't a key inside the
  # block). Two-space-indented top-level job headers.
  awk '
    /^  portability-shell-lint:/ { capture = 1; print; next }
    capture && /^  [a-z][a-z0-9_-]*:[[:space:]]*$/ { exit }
    capture { print }
  ' "$WORKFLOW"
}

test_start "portability_hard_fail"
if extract_portability_block | grep -Eq 'fail_on_shellcheck: *true'; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # portability shell-lint is still soft-fail (#857 regression)"
fi

test_start "portability_severity_warning"
if extract_portability_block | grep -Eq 'shellcheck_severity: *warning'; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # severity widened (warning) is the policy"
fi

# -----------------------------------------------------------------------------
# Behavioural: a synthetic portability bug must cause the same shellcheck
# invocation to exit non-zero. We use a small fixture script with an
# unmistakable warning-severity issue and run shellcheck against it with
# the same flags compliance-guard uses.
# -----------------------------------------------------------------------------

if command -v shellcheck >/dev/null 2>&1; then
  test_start "synthetic_finding_caught"
  fixture="$(mktemp -t cg_fixture.XXXXXX.sh)"
  # SC2155: declare-and-assign masks return value — warning severity.
  cat > "$fixture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
main() {
  local x="$(false || echo y)"
  echo "$x"
}
main "$@"
EOF
  if shellcheck -x -S warning -e SC1090,SC1091,SC2034 -f gcc "$fixture" >/dev/null 2>&1; then
    rm -f "$fixture"
    assert_exit_code 0 "false  # shellcheck silently accepted a SC2155 fixture"
  else
    rm -f "$fixture"
    assert_exit_code 0 "true"
  fi

  test_start "clean_fixture_passes"
  good="$(mktemp -t cg_good.XXXXXX.sh)"
  cat > "$good" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
main() {
  local x
  x="$(false || echo y)"
  echo "$x"
}
main "$@"
EOF
  if shellcheck -x -S warning -e SC1090,SC1091,SC2034 -f gcc "$good" >/dev/null 2>&1; then
    rm -f "$good"
    assert_exit_code 0 "true"
  else
    rm -f "$good"
    assert_exit_code 0 "false  # shellcheck rejected a clean fixture"
  fi
fi

# -----------------------------------------------------------------------------
# Sanity: every committed file under the lint corpus passes the same
# flags compliance-guard now applies. If this fails, the hard-fail flip
# would have surfaced findings — they must be fixed in the same PR.
# -----------------------------------------------------------------------------

if command -v shellcheck >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
  test_start "no_committed_findings"
  files=$(rg --files -g "*.sh" -g "!tests/**" 2>/dev/null)
  if [[ -n "$files" ]]; then
    # shellcheck disable=SC2086  # word-split is what we want here
    if echo "$files" | xargs shellcheck -x -S warning -e SC1090,SC1091,SC2034 -f gcc >/dev/null 2>&1; then
      assert_exit_code 0 "true"
    else
      assert_exit_code 0 "false  # committed shell tree fails portability lint"
    fi
  fi
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
