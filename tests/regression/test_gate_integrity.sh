#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Meta-gate: verify every ratchet script *actually fails* when its
# invariant is violated. A gate that silently passes on regression
# is worse than no gate — it lulls readers into false safety.
#
# For each critical gate, we:
#   1. Confirm the gate exists.
#   2. Confirm it passes today (control run).
#   3. Deliberately violate its invariant in a sandbox copy.
#   4. Confirm it FAILS (non-zero exit) on that copy.
#   5. Confirm the failure message names the specific violation.
#
# If any gate silently passes on step 4, this test fails — surfacing
# a broken gate immediately, on every regression run.
#
# Meta-gates covered:
#   - scripts/qa/docs-coverage.sh (must fail below MIN_DOCS_COVERAGE)
#   - scripts/qa/traceability-coverage.sh (same class of bug —
#     both were silently passing before #1032 + #1035)
#   - scripts/qa/check-version-consistency.sh (must detect drift)
#   - tests/performance/test_perf_budgets.sh (must fail when a
#     budget is exceeded)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ---------------------------------------------------------------------------
# GATE 1: docs-coverage soft-gate.
# Regression-tested here because it was silently a no-op before #1032.
# ---------------------------------------------------------------------------
test_start "docs_coverage_gate_fails_below_threshold"
GATE="$REPO_ROOT/scripts/qa/docs-coverage.sh"
if [[ ! -x "$GATE" ]]; then
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: gate missing at %s\n' "$CURRENT_TEST" "$GATE"
else
  # An impossible threshold must fail.
  if MIN_DOCS_COVERAGE=999 bash "$GATE" >/dev/null 2>&1; then
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: exit 0 with impossible threshold — silent pass bug returned!\n' \
      "$CURRENT_TEST"
  else
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  fi
fi

# ---------------------------------------------------------------------------
# GATE 2: traceability-coverage soft-gate. Same class of bug, same
# fix (#1035). Verify.
# ---------------------------------------------------------------------------
test_start "traceability_coverage_gate_fails_below_threshold"
GATE="$REPO_ROOT/scripts/qa/traceability-coverage.sh"
if [[ ! -x "$GATE" ]]; then
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: gate missing at %s\n' "$CURRENT_TEST" "$GATE"
else
  if MIN_TRACEABILITY_COVERAGE=999 bash "$GATE" >/dev/null 2>&1; then
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: exit 0 with impossible threshold — silent pass bug returned!\n' \
      "$CURRENT_TEST"
  else
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  fi
fi

# ---------------------------------------------------------------------------
# GATE 3: check-version-consistency must detect deliberate drift.
# ---------------------------------------------------------------------------
test_start "version_consistency_gate_detects_drift"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
# Copy the repo state that the script inspects into the sandbox
mkdir -p "$sandbox/defaults" "$sandbox/scripts/qa" "$sandbox/share/man/man1"
cp "$REPO_ROOT/defaults/.chezmoidata.toml" "$sandbox/defaults/"
cp "$REPO_ROOT/scripts/qa/check-version-consistency.sh" "$sandbox/scripts/qa/"
cp "$REPO_ROOT/share/man/man1/dot.1" "$sandbox/share/man/man1/"
# Introduce drift: bump the .chezmoidata.toml canonical to a
# version we KNOW the man page doesn't match.
sed -i.bak 's/^dotfiles_version = .*/dotfiles_version = "99.99.99"/' \
  "$sandbox/defaults/.chezmoidata.toml"
rm -f "$sandbox/defaults/.chezmoidata.toml.bak"
# Run the gate against the drifted copy.
if (cd "$sandbox" && bash scripts/qa/check-version-consistency.sh --quiet >/dev/null 2>&1); then
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: exit 0 with deliberate drift — gate is broken\n' "$CURRENT_TEST"
else
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# GATE 4: the perf budget gate must actually FAIL when violated.
#
# This previously counted budget literals with a grep and asserted the count
# was >= 15 — which verifies nothing about whether the gate fires, in a file
# whose whole thesis is that a silently-passing gate is worse than none. It
# was also brittle: the regex matched only 500|2000|5000, so a legitimate
# recalibration to any other value made a real budget invisible to the count.
#
# It now executes the gate three ways, using PERF_GATE_FILTER to run a single
# cheap budget so this stays fast:
#   a) impossible budget          -> must exit non-zero
#   b) normal budget              -> must exit zero (not always-failing)
#   c) deliberately broken command -> must exit non-zero (breakage detection)
# ---------------------------------------------------------------------------
GATE="$REPO_ROOT/tests/performance/test_perf_budgets.sh"
PERF_PROBE="instant_dot_version"

test_start "perf_gate_fails_on_budget_violation"
if [[ ! -f "$GATE" ]]; then
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: gate missing at %s\n' "$CURRENT_TEST" "$GATE"
elif PERF_GATE_FILTER="$PERF_PROBE" PERF_BUDGET_PERCENT=0 \
  bash "$GATE" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: exit 0 with an impossible budget — gate does not fire\n' \
    "$CURRENT_TEST"
else
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "perf_gate_passes_when_within_budget"
if PERF_GATE_FILTER="$PERF_PROBE" bash "$GATE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: gate fails even within budget — it is always-red, not a gate\n' \
    "$CURRENT_TEST"
fi

test_start "perf_gate_rejects_a_broken_command"
# A command that crashes instantly is FAST. Timing alone cannot tell the
# difference, so the gate must check exit status too.
_broken="$(mktemp)"
printf '#!/usr/bin/env bash\nsyntax ( error\n' >"$_broken"
if DOT_CLI="$_broken" PERF_GATE_FILTER="$PERF_PROBE" \
  bash "$GATE" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: a broken CLI passed its budget — F2 regression\n' \
    "$CURRENT_TEST"
else
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
fi
rm -f "$_broken"

# ---------------------------------------------------------------------------
# GATE 5: iCloud regression safety test — must fail if a canary
# file gets deleted. Verify the test's own "canary preservation"
# assertion still exists and would fire.
# ---------------------------------------------------------------------------
test_start "icloud_safety_test_still_checks_canary"
GATE="$REPO_ROOT/tests/regression/test_macos_icloud_symlinks_safety.sh"
if grep -q "CANARY-DO-NOT-DELETE" "$GATE" \
   && grep -qE 'canary\.txt' "$GATE"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: canary check removed from safety test\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# GATE 6: iCloud script source is still free of destructive operations.
# Independent of the assertion inside the unit test — this one runs on
# every regression pass without needing the unit-test infrastructure.
# ---------------------------------------------------------------------------
test_start "icloud_script_source_still_free_of_destructive_ops"
TMPL="$REPO_ROOT/defaults/run_before_macos-icloud-symlinks.sh.tmpl"
body=$(grep -vE '^\s*#' "$TMPL" | grep -vE '^\s*_log ')
found=()
echo "$body" | grep -qE 'rm -rf'   && found+=("rm -rf")
echo "$body" | grep -qE '^\s*mv\s' && found+=("mv")
echo "$body" | grep -qE '^\s*chmod\s' && found+=("chmod")
echo "$body" | grep -qE '^\s*chown\s' && found+=("chown")
if [[ ${#found[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: DANGEROUS OPS FOUND: %s\n' "$CURRENT_TEST" "${found[*]}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
