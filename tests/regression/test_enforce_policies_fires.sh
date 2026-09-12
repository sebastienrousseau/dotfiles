#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression: enforce-policies.sh must actually detect the things it claims
# to detect, and must not report violations on a clean repository.
#
# Regression for: GH-1087
# Why: The script spent a long time in a state where it could neither pass
# nor finish — >300s and five violations on a clean checkout, all false —
# while three of its checks silently detected nothing at all:
#
#   * `find -executable` is GNU-only, so the executable-text-file check was
#     an error-and-continue on every macOS machine, which is where this
#     runs as a pre-commit hook;
#   * file permissions compared an octal mode as a decimal number, so 764
#     passed while 775 failed;
#   * a bare `git ls-files` pathspec matches only at the repository root,
#     so a committed `.ssh/id_rsa` — the likeliest place for a private key
#     to appear — was not reported.
#
# None of that was visible from reading the script, and a green run proved
# nothing, because a check that finds nothing looks exactly like a check
# that passes. So this asserts in BOTH directions: clean repo stays silent,
# and each planted violation is caught by the specific check that owns it.

# NOT `set -e`: a failing `assert_*` returns non-zero, which under `-e`
# would kill the suite before the RESULTS: line is emitted.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck source=../framework/assertions.sh
source "$SCRIPT_DIR/../framework/assertions.sh"

# Safety net only. print_summary emits the RESULTS: line the runner parses,
# using assertions as the unit; this fires just once, and only if an
# unhandled non-zero killed the script before reaching it.
_emit_results() {
  [[ "${_RESULTS_EMITTED:-0}" == 1 ]] && return 0
  _RESULTS_EMITTED=1
  echo "RESULTS:$((TESTS_PASSED + TESTS_FAILED)):$TESTS_PASSED:$TESTS_FAILED"
}
trap _emit_results EXIT

SCRIPT="$REPO_ROOT/scripts/security/enforce-policies.sh"

test_start "enforce_policies_script_exists"
assert_file_exists "$SCRIPT" "the policy enforcement script should exist"

# -----------------------------------------------------------------------------
# Each scenario gets its own throwaway repository.
#
# One repository broken six ways cannot tell you which check fired, and an
# earlier version of this harness reported zero violations for everything
# because it had not copied lib/dot/ui.sh — the script died on line 19,
# before running a single check, and "no violations" was indistinguishable
# from "all clear". The baseline case below exists to catch exactly that:
# if the script cannot run, the planted cases go quiet too.
# -----------------------------------------------------------------------------

WORKDIR="$(mktemp -d -t enfpol.XXXXXX)"
trap 'rm -rf "$WORKDIR"; _emit_results' EXIT

RUN_OUT=""
RUN_RC=0

# Build a minimal repository, apply $1 as a shell snippet, commit, and run.
run_scenario() {
  local setup="$1"
  local dir="$WORKDIR/r$RANDOM$RANDOM"

  mkdir -p "$dir/scripts/security" "$dir/lib/dot" "$dir/config" \
    "$dir/.github/security-policies"
  cp "$SCRIPT" "$dir/scripts/security/"
  cp "$REPO_ROOT/lib/dot/ui.sh" "$dir/lib/dot/"
  [[ -f "$REPO_ROOT/config/gitleaks.toml" ]] &&
    cp "$REPO_ROOT/config/gitleaks.toml" "$dir/config/"
  # The OPA check counts a missing policy file as a violation, so the
  # scenario repository needs the real ones or every case fails for a
  # reason unrelated to what it is testing.
  cp "$REPO_ROOT"/.github/security-policies/*.rego \
    "$dir/.github/security-policies/" 2>/dev/null || true

  (
    cd "$dir" || exit 1
    git init -q .
    git config user.email test@example.com
    git config user.name test
    git config commit.gpgsign false
    eval "$setup"
    git add -A -f
    git commit -q -m scenario
  ) >/dev/null 2>&1

  RUN_RC=0
  RUN_OUT="$(cd "$dir" && NO_COLOR=1 "${BASH:-bash}" \
    ./scripts/security/enforce-policies.sh 2>&1)" || RUN_RC=$?
  rm -rf "$dir"
}

# -----------------------------------------------------------------------------
# 1. A clean repository must pass.
#
# This is the assertion that makes the rest meaningful: it proves the script
# runs to completion here, so a quiet result in a later case means "found
# nothing", not "never started".
# -----------------------------------------------------------------------------
test_start "clean_repository_reports_no_violations"
run_scenario "true"
assert_equals "0" "$RUN_RC" "a clean repository should exit 0"
assert_contains "Security policy enforcement completed successfully" "$RUN_OUT" \
  "and should say so explicitly"

# -----------------------------------------------------------------------------
# 2. A private key committed at a NESTED path.
#
# The bare pathspec bug: `git ls-files -- id_rsa` matches only at the root,
# so this exact case went undetected. A wildcard pathspec (`*.key`) spans
# directories, which is why the bug was invisible in half the patterns.
# -----------------------------------------------------------------------------
test_start "nested_private_key_is_detected"
run_scenario 'mkdir -p .ssh && printf -- "-----BEGIN OPENSSH PRIVATE KEY-----\nx\n-----END OPENSSH PRIVATE KEY-----\n" > .ssh/id_rsa'
assert_not_equals "0" "$RUN_RC" "a committed private key must fail the gate"
assert_contains ".ssh/id_rsa" "$RUN_OUT" \
  "and the sensitive-file check must name the nested path"

test_start "root_private_key_is_detected"
run_scenario 'printf -- "-----BEGIN RSA PRIVATE KEY-----\nx\n-----END RSA PRIVATE KEY-----\n" > id_rsa'
assert_not_equals "0" "$RUN_RC" "a committed private key must fail the gate"
assert_contains "Sensitive file committed" "$RUN_OUT" \
  "and must be reported by the sensitive-file check"

# -----------------------------------------------------------------------------
# 3. A credential shape in a tracked file.
#
# Split so the literal never appears in this file: the pattern list is a
# grep over tracked files, and a test that spells out a matching key makes
# the repository fail its own gate.
# -----------------------------------------------------------------------------
test_start "aws_key_shape_is_detected"
run_scenario 'printf "aws_key = AKIA%s\n" "IOSFODNN7EXAMPLE" > notes.md'
assert_not_equals "0" "$RUN_RC" "a committed AWS key must fail the gate"
assert_contains "Credential pattern" "$RUN_OUT" \
  "and must be reported by the pattern scan"

# -----------------------------------------------------------------------------
# 4. Permissions. One file trips both checks: world-writable (the octal-as-
#    decimal bug) and executable-text (the GNU-only `find -executable` bug).
# -----------------------------------------------------------------------------
test_start "world_writable_tracked_file_is_detected"
run_scenario 'echo hi > NOTES.md && chmod 777 NOTES.md'
assert_not_equals "0" "$RUN_RC" "a world-writable tracked file must fail the gate"
assert_contains "World-writable file" "$RUN_OUT" \
  "the permission check must fire"
assert_contains "Executable text file" "$RUN_OUT" \
  "and the executable-text check must fire on the same file"

# A tracked symlink must NOT be reported. A symlink carries its own mode bits
# but the kernel ignores them — access is governed by the target — and they are
# not portable: Linux creates symlinks 777, macOS 755. This repository tracks
# eight of them (.gitleaks.toml, .pre-commit-config.yaml and friends, all
# pointing into config/), which passed on a Mac and failed on an Ubuntu runner
# for that reason alone.
#
# `chmod -h` sets the link's own bits on macOS and is unsupported on Linux,
# where the link is already 777 — so after this line the scenario is a
# world-writable symlink on both platforms, and the test means the same thing
# in both places rather than passing trivially on one.
test_start "tracked_symlink_is_not_flagged_for_permissions"
run_scenario 'echo hi > real.txt && ln -s real.txt link.toml && chmod -h 777 link.toml 2>/dev/null || true'
assert_equals "0" "$RUN_RC" "a tracked symlink must not fail the gate"
assert_false '[[ "$RUN_OUT" == *"link.toml"* ]]' \
  "and must not be named by either permission check"

# -----------------------------------------------------------------------------
# 5. A shellcheck error in a tracked script.
# -----------------------------------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  test_start "shellcheck_error_in_tracked_script_is_detected"
  run_scenario 'printf "#!/usr/bin/env bash\nif [ \$x = 1 ]\n" > broken.sh'
  assert_not_equals "0" "$RUN_RC" "a broken script must fail the gate"
  assert_contains "ShellCheck errors in" "$RUN_OUT" \
    "and must be reported by the shell-script check"
else
  test_start "shellcheck_check_skipped_without_shellcheck"
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s (skipped: shellcheck not installed)\n' "$CURRENT_TEST"
fi

# -----------------------------------------------------------------------------
# 6. A missing optional tool must skip ONE check, not abort the run.
#
# opa, gitleaks and shellcheck were all fatal dependencies, so a machine
# without opa ran no checks at all. As a pre-commit hook that is a gate
# which silently does nothing, which is worse than one that is noisy.
# -----------------------------------------------------------------------------
test_start "missing_optional_tool_skips_only_its_own_check"
run_scenario "true"
assert_equals "0" "$RUN_RC" "a missing optional tool must not abort the run"
assert_false '[[ "$RUN_OUT" == *"Missing required tools"* ]]' \
  "opa/gitleaks/shellcheck must not be fatal dependencies"

# A skip must never be rendered as a pass.
test_start "a_skipped_check_is_not_reported_as_passing"
assert_true "grep -q 'SKIPPED' '$SCRIPT'" \
  "the script must have a distinct SKIPPED state"
assert_file_contains "$SCRIPT" "DOTFILES_POLICY_STRICT" \
  "and a strict mode that turns a skip into an error for CI"

_RESULTS_EMITTED=1
print_summary
