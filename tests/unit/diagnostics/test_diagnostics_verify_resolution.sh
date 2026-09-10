#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for scripts/diagnostics/verify.sh.
#
# test_diagnostics_verify_command.sh greps the source and runs the script once
# through the generic safe-mode exerciser, which only ever reaches the first
# resolution branch. This file drives the script for real: every arm of
# resolve_dot_bin, both arms of run_step, both arms of the chezmoi-diff check
# and both verdicts.
#
# Everything runs against a per-case fake HOME with a PATH that contains only
# the stubs the case wants found, so nothing here can reach the real `dot`,
# the real `chezmoi`, or the real checkout.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

VERIFY_FILE="$REPO_ROOT/scripts/diagnostics/verify.sh"

WORK="$(mktemp -d -t vfy.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

# vfy_case <name> — a fresh, empty fake HOME plus an empty stub bin dir.
# Prints the case root; $root/home and $root/bin are the two interesting
# subdirectories.
vfy_case() {
  local root="$WORK/$1"
  rm -rf "$root"
  mkdir -p "$root/home" "$root/bin"
  printf '%s\n' "$root"
}

# vfy_stub <dir> <name> <exit-code> — a stub executable that prints its own
# name and arguments, then exits with the given status. `#!/bin/sh` on
# purpose: the case PATH deliberately hides most of the system, and a
# `/usr/bin/env bash` shebang would resolve through it.
vfy_stub() {
  local dir="$1" name="$2" rc="${3:-0}"
  {
    printf '#!/bin/sh\n'
    printf 'printf "%%s %%s\\n" "%s" "$*"\n' "$name"
    printf 'exit %s\n' "$rc"
  } >"$dir/$name"
  chmod +x "$dir/$name"
}

# vfy_run <root> [args...] — run verify.sh with the case's HOME and a PATH
# whose only non-system entry is the case's stub dir. CHEZMOI_SOURCE_DIR is
# passed through from the caller's environment when set.
#
# The interpreter is "$BASH" — the absolute path of the shell running this
# suite — not a bare `bash`. The case PATH puts /bin ahead of anything else,
# and on macOS that resolves to bash 3.2, which has no BASH_XTRACEFD: its
# xtrace would go to stderr and be swallowed by the capture below, so the
# script would run without being measured.
VFY_OUT=""
VFY_RC=0
vfy_run() {
  local root="$1"
  shift
  VFY_RC=0
  VFY_OUT="$(
    HOME="$root/home" \
      PATH="$root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      CHEZMOI_SOURCE_DIR="${VFY_CHEZMOI_SRC:-}" \
      NO_COLOR=1 \
      "${BASH:-bash}" "$VERIFY_FILE" "$@" 2>&1
  )" || VFY_RC=$?
  printf '%s' "$VFY_OUT" >/dev/null
}

# ── 1. `dot` on PATH, everything green ─────────────────────────────────────
root="$(vfy_case path_ok)"
vfy_stub "$root/bin" dot 0
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="" vfy_run "$root"

test_start "verify_passes_when_dot_and_chezmoi_are_healthy"
assert_equals "0" "$VFY_RC" "a healthy environment should exit 0"

test_start "verify_reports_all_checks_passed"
assert_contains "all checks passed" "$VFY_OUT" "the clean verdict should be printed"

test_start "verify_runs_doctor_and_status_by_default"
assert_contains "dot doctor" "$VFY_OUT" "the default run should invoke doctor"

test_start "verify_reports_a_clean_chezmoi_diff"
assert_contains "clean" "$VFY_OUT" "a zero-exit chezmoi diff should read as clean"

# ── 2. --security swaps the two default steps for security-score ───────────
root="$(vfy_case security)"
vfy_stub "$root/bin" dot 0
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="" vfy_run "$root" --security

test_start "verify_security_flag_exits_clean"
assert_equals "0" "$VFY_RC" "--security should exit 0 when the score command passes"

test_start "verify_security_flag_runs_security_score"
assert_contains "security-score" "$VFY_OUT" "--security should run the score step"

test_start "verify_security_flag_skips_doctor"
assert_false "[[ \"\$VFY_OUT\" == *'dot doctor'* ]]" \
  "--security should replace the doctor/status pair, not add to it"

# ── 3. A failing step is counted, not fatal ────────────────────────────────
root="$(vfy_case step_fails)"
vfy_stub "$root/bin" dot 3
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="" vfy_run "$root"

test_start "verify_fails_when_a_step_fails"
assert_equals "1" "$VFY_RC" "a failing dot step should make verify exit 1"

test_start "verify_names_the_failing_step_exit_code"
assert_contains "exit 3" "$VFY_OUT" "the step's exit code should be surfaced"

test_start "verify_prints_the_remediation_hint"
assert_contains "dot heal" "$VFY_OUT" "the failure verdict should suggest dot heal"

# ── 4. chezmoi diff reporting drift ────────────────────────────────────────
root="$(vfy_case diff_drift)"
vfy_stub "$root/bin" dot 0
vfy_stub "$root/bin" chezmoi 1
VFY_CHEZMOI_SRC="" vfy_run "$root"

test_start "verify_fails_on_chezmoi_drift"
assert_equals "1" "$VFY_RC" "a non-zero chezmoi diff should make verify exit 1"

test_start "verify_reports_drift"
assert_contains "drift detected" "$VFY_OUT" "drift should be named"

test_start "verify_echoes_the_diff_output"
assert_contains "chezmoi diff" "$VFY_OUT" "the captured diff body should be replayed"

# ── 5. Resolution fallbacks, in the order resolve_dot_bin tries them ───────

# 5a. ~/.local/bin/dot when PATH has none.
root="$(vfy_case home_local_bin)"
mkdir -p "$root/home/.local/bin"
vfy_stub "$root/home/.local/bin" dot 0
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="" vfy_run "$root"

test_start "verify_falls_back_to_home_local_bin"
assert_equals "0" "$VFY_RC" "the home-local-bin fallback should be found and used"

# 5b. $CHEZMOI_SOURCE_DIR/bin/dot.
root="$(vfy_case chezmoi_src)"
mkdir -p "$root/src/bin"
vfy_stub "$root/src/bin" dot 0
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="$root/src" vfy_run "$root"

test_start "verify_falls_back_to_chezmoi_source_dir"
assert_equals "0" "$VFY_RC" "CHEZMOI_SOURCE_DIR/bin/dot should be found and used"

# 5c. ~/.dotfiles/bin/dot.
root="$(vfy_case home_dotfiles)"
mkdir -p "$root/home/.dotfiles/bin"
vfy_stub "$root/home/.dotfiles/bin" dot 0
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="" vfy_run "$root"

test_start "verify_falls_back_to_home_dotfiles"
assert_equals "0" "$VFY_RC" "the home-dotfiles fallback should be found and used"

# 5d. ~/.local/share/chezmoi/bin/dot.
root="$(vfy_case home_share_chezmoi)"
mkdir -p "$root/home/.local/share/chezmoi/bin"
vfy_stub "$root/home/.local/share/chezmoi/bin" dot 0
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="" vfy_run "$root"

test_start "verify_falls_back_to_local_share_chezmoi"
assert_equals "0" "$VFY_RC" "the local-share-chezmoi fallback should be found and used"

# 5e. A source directory that exists but holds no dot binary — resolution
#     must give up rather than half-succeed.
root="$(vfy_case src_without_dot)"
mkdir -p "$root/src"
vfy_stub "$root/bin" chezmoi 0
VFY_CHEZMOI_SRC="$root/src" vfy_run "$root"

test_start "verify_reports_a_missing_dot_binary"
assert_equals "1" "$VFY_RC" "no reachable dot binary should make verify exit 1"

test_start "verify_names_the_missing_dot_binary"
assert_contains "not found in PATH" "$VFY_OUT" \
  "the missing-binary failure should say where it looked"

print_summary
