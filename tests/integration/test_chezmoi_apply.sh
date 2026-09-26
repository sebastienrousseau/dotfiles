#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for scripts/ops/chezmoi-apply.sh
# Tests idempotency, help output, and error handling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

APPLY_SCRIPT="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"

# ── Script existence and structure ──────────────────────────────

test_start "chezmoi_apply_exists"
assert_file_exists "$APPLY_SCRIPT" "chezmoi-apply.sh should exist"

test_start "chezmoi_apply_executable"
if [[ -x "$APPLY_SCRIPT" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: chezmoi-apply.sh is executable"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: chezmoi-apply.sh should be executable"
fi

test_start "chezmoi_apply_shebang"
first_line=$(head -n 1 "$APPLY_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "chezmoi_apply_strict_mode"
if grep -q 'set -euo pipefail' "$APPLY_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses strict mode"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# ── Help output ─────────────────────────────────────────────────

test_start "chezmoi_apply_help"
help_out=$("$APPLY_SCRIPT" --help 2>&1 || true)
if echo "$help_out" | grep -qi "usage\|apply"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: --help shows usage info"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: --help should show usage info"
fi

# ── Idempotency check ──────────────────────────────────────────

# Both cases apply THIS checkout to a throwaway destination with an empty
# config: without --source/--destination they used the host's own chezmoi
# source and home, so on a clean runner they errored and locally they
# dry-ran the user's real home. Scripts, externals and encrypted files are
# excluded, so nothing is installed or downloaded.
CZ_SB=""
if command -v chezmoi >/dev/null 2>&1; then
  CZ_SB="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/cz-apply.XXXXXX")" && pwd)"
  trap 'rm -rf "$CZ_SB"' EXIT
  mkdir -p "$CZ_SB/home"
  : >"$CZ_SB/chezmoi.toml"
fi
cz() {
  env -i HOME="$CZ_SB/home" PATH="/usr/bin:/bin" "$(command -v chezmoi)" \
    --config "$CZ_SB/chezmoi.toml" --source "$REPO_ROOT" --destination "$CZ_SB/home" \
    --cache "$CZ_SB/cache" --persistent-state "$CZ_SB/state.boltdb" "$@"
}
CZ_EXCLUDE=(--exclude=scripts,externals,encrypted)

test_start "chezmoi_apply_dry_run"
if [[ -n "$CZ_SB" ]]; then
  exit_code=0
  dry_run_err="$(cz apply --dry-run "${CZ_EXCLUDE[@]}" 2>&1 >/dev/null)" || exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dry-run of the checkout succeeds (templates valid)"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dry-run failed (exit=$exit_code): ${dry_run_err:0:300}"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (chezmoi not available)"
fi

test_start "chezmoi_apply_idempotent"
if [[ -n "$CZ_SB" ]]; then
  apply_rc=0
  cz apply "${CZ_EXCLUDE[@]}" >/dev/null 2>&1 || apply_rc=$?
  diff_out="$(cz diff "${CZ_EXCLUDE[@]}" 2>/dev/null || true)"
  if [[ $apply_rc -eq 0 && -z "$diff_out" && -f "$CZ_SB/home/.zshrc" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: apply, then diff shows no pending changes"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: apply rc=$apply_rc; pending after apply: ${diff_out:0:300}"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (chezmoi not available)"
fi

# ── Environment variable support ──────────────────────────────

test_start "chezmoi_apply_env_vars"
if grep -q 'DOTFILES_CHEZMOI_APPLY_FLAGS' "$APPLY_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports DOTFILES_CHEZMOI_APPLY_FLAGS"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support custom flags env var"
fi

test_start "chezmoi_apply_verbose_env"
if grep -q 'DOTFILES_CHEZMOI_VERBOSE' "$APPLY_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports verbose env var"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support DOTFILES_CHEZMOI_VERBOSE"
fi

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "Chezmoi apply integration tests completed."
print_summary
