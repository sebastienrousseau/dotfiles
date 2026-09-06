#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Argument and confirmation tests for scripts/ops/chezmoi-remove.sh.
#
# The script's last act is `chezmoi remove`, which would delete real
# managed files, so every case runs with PATH pointing at a `chezmoi`
# shim that records its argv instead. The tests assert both the
# confirmation behaviour and the exact command that would have run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

CR_FILE="$REPO_ROOT/scripts/ops/chezmoi-remove.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
CRBIN="$TMP/cr-bin"
CALLS="$TMP/cr-calls.log"
mkdir -p "$CRBIN"
for tool in cat env printf sed grep; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$CRBIN/$tool"
done
ln -sf "$BASH" "$CRBIN/bash"
cat >"$CRBIN/chezmoi" <<EOF
#!/usr/bin/env bash
printf 'chezmoi %s\n' "\$*" >>"$CALLS"
exit 0
EOF
chmod +x "$CRBIN/chezmoi"

CR_OUT=""
CR_RC=0
# _run_cr <answer> [args...]
_run_cr() {
  local answer="$1"
  shift
  CR_RC=0
  : >"$CALLS"
  CR_OUT="$(
    printf '%s\n' "$answer" |
      env BASH_XTRACEFD=21 PATH="$CRBIN" HOME="$TMP/cr-home" "$BASH" "$CR_FILE" "$@" 2>&1
  )" || CR_RC=$?
}

_cr_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$CR_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $CR_RC"
  for needle in "$@"; do
    [[ "$CR_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$CR_OUT" | sed 's/^/      /'
  fi
}

_cr_ran() {
  local label="$1" expected="$2"
  test_start "$label"
  if grep -qF -- "$expected" "$CALLS" 2>/dev/null; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected chezmoi call '$expected'"
    sed 's/^/      /' "$CALLS" 2>/dev/null || printf '      (no calls recorded)\n'
  fi
}

_cr_ran_nothing() {
  test_start "$1"
  if [[ ! -s "$CALLS" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: chezmoi must not have been invoked"
    sed 's/^/      /' "$CALLS"
  fi
}

mkdir -p "$TMP/cr-home"

# =======================================================================
# 1. Argument guards.
# =======================================================================
_run_cr n
_cr_expect "no_arguments_exits_1" 1 "Usage: dot remove <path> [--source] [--dry-run]"
_cr_ran_nothing "no_arguments_runs_no_chezmoi"

_run_cr n --source
_cr_expect "flags_without_a_path_exit_1" 1 "No path provided."
_cr_ran_nothing "flags_without_a_path_run_no_chezmoi"

_run_cr n --dry-run --source
_cr_expect "both_flags_without_a_path_exit_1" 1 "No path provided."

# =======================================================================
# 2. Confirmation: anything but y/Y aborts before touching chezmoi.
# =======================================================================
_run_cr n .bashrc
_cr_expect "declining_the_prompt_aborts" 1 \
  "About to run: chezmoi remove --keep-source .bashrc" "Aborted."
_cr_ran_nothing "declining_the_prompt_runs_no_chezmoi"

_run_cr "" .bashrc
_cr_expect "empty_answer_aborts" 1 "Aborted."

# =======================================================================
# 3. Accepted removals, and how the flags shape the chezmoi argv.
# =======================================================================
_run_cr y .bashrc
_cr_expect "default_removal_keeps_the_source" 0 \
  "About to run: chezmoi remove --keep-source .bashrc"
_cr_ran "default_removal_invokes_chezmoi" "chezmoi remove --keep-source .bashrc"

_run_cr Y .bashrc
_cr_expect "uppercase_y_is_accepted" 0 "About to run:"
_cr_ran "uppercase_y_invokes_chezmoi" "chezmoi remove --keep-source .bashrc"

_run_cr y --source .bashrc
_cr_expect "source_flag_drops_keep_source" 0 "About to run: chezmoi remove  .bashrc"
_cr_ran "source_flag_invokes_chezmoi_without_keep_source" "chezmoi remove .bashrc"

_run_cr y --dry-run .bashrc
_cr_ran "dry_run_flag_is_forwarded" "chezmoi remove --dry-run --keep-source .bashrc"

_run_cr y --dry-run --source .zshrc .vimrc
_cr_ran "multiple_paths_and_flags_are_forwarded" "chezmoi remove --dry-run .zshrc .vimrc"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
