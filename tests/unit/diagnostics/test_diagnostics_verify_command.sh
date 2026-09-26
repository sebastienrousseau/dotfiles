#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot verify diagnostics script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

VERIFY_FILE="$REPO_ROOT/scripts/diagnostics/verify.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "verify_command_file_exists"
assert_file_exists "$VERIFY_FILE" "verify.sh should exist"

test_start "verify_command_syntax_valid"
if bash -n "$VERIFY_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Stub `dot` and `chezmoi` on PATH: dot records its argv (and fails when
# asked to), chezmoi prints $STUB_DIFF as its diff and exits 0 as the real
# one does, drift or not.
VFY="$DOTFILES_COV_TMPDIR/verify"
mkdir -p "$VFY/bin"
cat >"$VFY/bin/dot" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$VFY_CALLS"
[[ "$1" == "${VFY_FAIL:-}" ]] && exit 3
exit 0
STUB
cat >"$VFY/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf '%s' "${STUB_DIFF:-}"
exit 0
STUB
chmod +x "$VFY/bin/dot" "$VFY/bin/chezmoi"

# verify [args...]: runs verify.sh; sets rc, out and calls (dot argv, one per line).
verify() {
  : >"$VFY/calls"
  out=$(PATH="$VFY/bin:$PATH" VFY_CALLS="$VFY/calls" bash "$VERIFY_FILE" "$@" 2>&1)
  rc=$?
  calls=$(tr '\n' ' ' <"$VFY/calls")
}

test_start "verify_clean_passes"
STUB_DIFF="" verify
assert_equals "0" "$rc" "no drift and passing dot steps exit 0"

test_start "verify_runs_doctor_then_status"
assert_equals "doctor status " "$calls" "default mode runs dot doctor and dot status"

test_start "verify_drift_fails_even_though_chezmoi_diff_exits_0"
STUB_DIFF=$'diff --git a/.zshrc b/.zshrc\n+changed\n' verify
assert_equals "1" "$rc" "diff output is drift"

test_start "verify_drift_shows_the_diff"
assert_contains "+changed" "$out" "the drift itself is printed"

test_start "verify_failed_step_fails"
STUB_DIFF="" VFY_FAIL=doctor verify
assert_equals "1:1" "$rc:$(grep -c 'failed (exit 3)' <<<"$out")" "a failing dot doctor fails verify and reports its exit code"

for flag in --security -s; do
  test_start "verify_security_mode_${flag//-/}"
  STUB_DIFF="" verify "$flag"
  assert_equals "security-score " "$calls" "$flag runs only dot security-score"
done

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$VERIFY_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
