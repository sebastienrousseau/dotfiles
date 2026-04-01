#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Static code analysis — mirrors Codacy checks locally.
# Catches shellcheck warnings, unsafe patterns, and code quality issues
# that would fail the Codacy gate in CI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ═══════════════════════════════════════════════════════════════
# 1. SHELLCHECK — warning level (matches Codacy severity)
# ═══════════════════════════════════════════════════════════════

# Files modified in this branch (v0.2.499 changes)
CHANGED_SCRIPTS=(
  scripts/dot/commands/ai.sh
  scripts/ops/chezmoi-apply.sh
  scripts/ops/prewarm.sh
  scripts/ops/ai-setup.sh
  scripts/uninstall.sh
  .chezmoitemplates/aliases/ai/ai.aliases.sh
  .chezmoitemplates/aliases/default/default.aliases.sh
  .chezmoitemplates/functions/api/apihealth.sh
  .chezmoitemplates/functions/misc/caffeine.sh
  .chezmoitemplates/functions/system/environment.sh
  install.sh
)

test_start "shellcheck_error_level"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031 "$filepath" >/dev/null 2>&1; then
    printf '    shellcheck error: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all changed scripts must pass shellcheck at error level"

test_start "shellcheck_warning_level_new_scripts"
# New scripts added in this branch must be clean at warning level
NEW_SCRIPTS=(
  scripts/uninstall.sh
)
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! shellcheck --severity=warning -e SC1090 -e SC1091 -e SC2030 -e SC2031 "$filepath" >/dev/null 2>&1; then
    printf '    shellcheck warning: %s\n' "$f"
    shellcheck --severity=warning -e SC1090 -e SC1091 -e SC2030 -e SC2031 "$filepath" 2>&1 | head -5
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts must pass shellcheck at warning level"

# ═══════════════════════════════════════════════════════════════
# 2. SC2155 — declare and assign separately
# ═══════════════════════════════════════════════════════════════

test_start "no_sc2155_local_assign_in_changed_files"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -qE '^\s*local\s+\w+=\$\(' "$filepath" 2>/dev/null; then
    count=$(grep -cE '^\s*local\s+\w+=\$\(' "$filepath" 2>/dev/null)
    printf '    SC2155 in %s: %s instances\n' "$f" "$count"
    failures=$((failures + count))
  fi
done
assert_equals "0" "$failures" "no local var=\$(cmd) pattern (SC2155)"

# ═══════════════════════════════════════════════════════════════
# 3. SC2015 — A && B || C is not if-then-else
# ═══════════════════════════════════════════════════════════════

test_start "no_sc2015_and_or_in_new_scripts"
# Only check new scripts added in this branch for SC2015
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  unsafe=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -E '&&.*\|\|' | grep -vcE '\|\|\s*(true|:|continue|break|return)' || true)
  unsafe=$(echo "$unsafe" | tr -d '[:space:]')
  unsafe="${unsafe:-0}"
  if [[ "$unsafe" -gt 0 ]]; then
    printf '    SC2015 in %s: %s unsafe instances\n' "$f" "$unsafe"
    failures=$((failures + unsafe))
  fi
done
assert_equals "0" "$failures" "no unsafe A && B || C in new scripts (SC2015)"

# ═══════════════════════════════════════════════════════════════
# 4. SC2086 — unquoted variables in critical paths
# ═══════════════════════════════════════════════════════════════

test_start "no_unquoted_vars_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if shellcheck -S warning -e SC1090,SC1091,SC2030,SC2031 --format=gcc "$filepath" 2>&1 | grep -q 'SC2086'; then
    count=$(shellcheck -S warning -e SC1090,SC1091,SC2030,SC2031 --format=gcc "$filepath" 2>&1 | grep -c 'SC2086')
    printf '    SC2086 in %s: %s unquoted vars\n' "$f" "$count"
    failures=$((failures + count))
  fi
done
assert_equals "0" "$failures" "new scripts must not have unquoted variables (SC2086)"

# ═══════════════════════════════════════════════════════════════
# 5. SHFMT — formatting compliance
# ═══════════════════════════════════════════════════════════════

test_start "shfmt_formatting"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! shfmt -d -i 2 -ci "$filepath" >/dev/null 2>&1; then
    printf '    shfmt: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all changed scripts must pass shfmt -i 2 -ci"

# ═══════════════════════════════════════════════════════════════
# 6. BASH SYNTAX — all changed scripts must parse
# ═══════════════════════════════════════════════════════════════

test_start "bash_syntax_all_changed"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! bash -n "$filepath" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all changed scripts must have valid bash syntax"

# ═══════════════════════════════════════════════════════════════
# 7. UNSAFE PATTERNS — Codacy custom checks
# ═══════════════════════════════════════════════════════════════

test_start "no_eval_in_new_scripts"
# New scripts should not use eval (except in test framework)
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\beval\b'; then
    eval_count=$(grep -vE '^\s*#' "$filepath" | grep -cE '\beval\b')
    printf '    eval in %s: %s instances\n' "$f" "$eval_count"
    failures=$((failures + eval_count))
  fi
done
assert_equals "0" "$failures" "new scripts must not use eval"

test_start "no_curl_pipe_sh"
# No curl | sh or wget | sh in any changed file
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE 'curl.*\|\s*(ba)?sh|wget.*\|\s*(ba)?sh'; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no curl|sh or wget|sh in changed files"

test_start "no_chmod_777"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -qE 'chmod.*777|chmod.*666' "$filepath" 2>/dev/null; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no chmod 777/666 in changed files"

test_start "no_hardcoded_tmp"
# Changed scripts should use mktemp, not hardcoded /tmp paths
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '>/tmp/[a-z]'; then
    printf '    hardcoded /tmp in %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no hardcoded /tmp paths in changed files"

# ═══════════════════════════════════════════════════════════════
# 8. REGRESSION TESTS THEMSELVES — must be clean
# ═══════════════════════════════════════════════════════════════

test_start "regression_tests_syntax"
failures=0
for f in "$REPO_ROOT"/tests/regression/test_*.sh; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all regression test files must have valid syntax"

test_start "regression_tests_no_local_outside_function"
# Regression tests must not use 'local' outside functions (bash error)
failures=0
for f in "$REPO_ROOT"/tests/regression/test_*.sh; do
  if grep -qE '^local ' "$f" 2>/dev/null; then
    printf '    local outside function in %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no 'local' outside functions in regression tests"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
