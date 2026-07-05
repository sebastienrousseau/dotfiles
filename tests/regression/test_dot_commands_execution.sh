#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression: every safe-to-run `dot` subcommand executes cleanly.
#
# Companion to `test_dot_subcommand_smoke.sh` (which validates the
# route table + help entries). This test goes further: it actually
# EXECUTES each read-only subcommand and asserts:
#
#   1. Exit code 0 (or a documented non-zero for commands that
#      signal state via rc).
#   2. Stderr does NOT contain "No such file or directory" (the
#      classic wrong-path bug — see the aliases-manifest.sh /
#      run_script fixes at commit fix/dot-command-bugs).
#   3. Stderr does NOT contain "jq: error: Could not open file" (the
#      registry curl-newline bug).
#   4. Stderr does NOT contain "unbound variable" or "not found"
#      surfaces that indicate a broken sub-dispatcher.
#   5. For known-populated LIST commands, stdout is not empty.
#
# Regression baseline: commit fix/dot-command-bugs (v0.2.510)
# which fixed 9 command bugs discovered by full audit:
#   - aliases-manifest.sh path (Phase-4b descent missing)
#   - run_script central path resolution
#   - agent a2a-card wrong-side descent (.well-known/ at repo root)
#   - version-locks.sh $src_dir vs $cm_src
#   - detect-collisions.py hardcoded pre-4b path
#   - verify_state.sh relative-path assumption
#   - fleet.sh grep|tail|sed pipefail cascade
#   - tools.sh pipx list --short pipefail cascade
#   - registry.sh curl stray-newline poisoning $index
#
# Mutating commands (sync, apply, edit, commit, install, upgrade,
# add, rollback, uninstall) are explicitly SKIPPED so the test is
# safe to run on any workstation without side effects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

# Sandbox HOME so commands that read user config don't pull from
# the real machine and so any speculative writes land in tmp. Mirror
# the pattern used by test_dot_subcommand_smoke.sh so both tests
# stay comparable.
sandbox="$(mktemp -d -t dot-exec.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.config" "$sandbox/.local/share" "$sandbox/.cache" \
  "$sandbox/.local/state"
ln -s "$REPO_ROOT" "$sandbox/.dotfiles"
export HOME="$sandbox" \
  XDG_CONFIG_HOME="$sandbox/.config" \
  XDG_DATA_HOME="$sandbox/.local/share" \
  XDG_CACHE_HOME="$sandbox/.cache" \
  XDG_STATE_HOME="$sandbox/.local/state" \
  CHEZMOI_SOURCE_DIR="$REPO_ROOT"

# Patterns that MUST NOT appear in stderr for any command. These
# are the specific failure modes the audit turned up; any of them
# indicates a real bug that this test is designed to catch.
readonly -a FORBIDDEN_STDERR_PATTERNS=(
  "No such file or directory"
  "unbound variable"
  "command not found"
  "Could not open file"
  "not a valid command"
  "unknown subcommand"
)

# Commands to exercise. Format: `dot ARGS`, where ARGS is
# whitespace-separated. Each is run with a 15s timeout.
#
# We deliberately test READ-ONLY subcommands. Mutating commands
# (sync/apply/commit/install/upgrade/add/edit/rollback/uninstall)
# are covered by other test suites and are skipped here for safety.
readonly -a SAFE_COMMANDS=(
  # Top-level info
  "version"
  "help"
  "search dot"

  # Aliases (the class this test protects against by name).
  # `aliases stats` is intentionally omitted: it requires a
  # populated ~/.zsh_history which the sandbox does not provide.
  # Its behaviour when history is missing (die with a clear error)
  # is correct.
  "aliases list"
  "aliases tiers"

  # Agent / Meta
  "agent card"
  "agent a2a-card"
  "mode current"
  "mode list"
  "mode doctor"

  # Config / Env
  "env list"
  "profile show"
  "theme current"
  "theme list"

  # Diagnostics — read-only
  "status"
  "cd"
  "diff"
  "locks"
  "packages"
  "keys sign-check"
  "secret-audit"

  # Fleet
  "fleet status"
  "fleet drift"
  "fleet events"

  # MCP
  "mcp doctor"
  "mcp registry"

  # AI
  "ai tools"

  # Registry (was silently broken pre-fix)
  "registry list"
  "registry url"
)

# ═══════════════════════════════════════════════════════════════
# Helper: run a `dot` command safely, capture stdout + stderr, and
# assert the FORBIDDEN patterns don't appear in stderr.
# ═══════════════════════════════════════════════════════════════

run_dot_and_assert_clean() {
  local args="$1"
  local test_name
  test_name="$(echo "$args" | tr ' ' '_')"
  test_start "exec_dot_${test_name}"

  local stdout_file stderr_file exit_code
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f $stdout_file $stderr_file" RETURN

  # shellcheck disable=SC2086
  timeout 15 bash "$DOT_CLI" $args \
    >"$stdout_file" 2>"$stderr_file" \
    && exit_code=0 || exit_code=$?

  local failure_reasons=()

  # ── Assertion 1: exit code should be 0 (or 1 for known-signal
  # commands like `dot score` which signals via rc).
  if [[ $exit_code -ne 0 && $exit_code -ne 1 ]]; then
    failure_reasons+=("exit code=$exit_code (expected 0 or 1)")
  fi

  # ── Assertion 2-5: no forbidden pattern in stderr.
  local pattern
  for pattern in "${FORBIDDEN_STDERR_PATTERNS[@]}"; do
    if grep -q -F "$pattern" "$stderr_file"; then
      failure_reasons+=("stderr contains: '$pattern'")
    fi
  done

  # ── Assertion 6: LIST commands should produce non-empty stdout.
  # `list`, `stats`, `status`, `current`, `card` are all
  # information-emitting subcommands.
  if [[ "$args" == *" list" ]] || [[ "$args" == *" status" ]] \
      || [[ "$args" == *" stats" ]] || [[ "$args" == *" card" ]] \
      || [[ "$args" == *" current" ]]; then
    if [[ ! -s "$stdout_file" ]]; then
      failure_reasons+=("stdout empty (expected content for list-style command)")
    fi
  fi

  if [[ ${#failure_reasons[@]} -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
    for r in "${failure_reasons[@]}"; do
      printf '        %s\n' "$r"
    done
    # Print first few lines of stderr for triage.
    if [[ -s "$stderr_file" ]]; then
      printf '        stderr (first 3 lines):\n'
      head -3 "$stderr_file" | sed 's/^/          /'
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════
# Run the matrix
# ═══════════════════════════════════════════════════════════════

echo
echo "── dot command execution regression (${#SAFE_COMMANDS[@]} commands) ──"
echo

for args in "${SAFE_COMMANDS[@]}"; do
  run_dot_and_assert_clean "$args"
done

echo
echo "── Summary ──"
echo "  RUN:    $((TESTS_PASSED + TESTS_FAILED))"
echo "  PASSED: $TESTS_PASSED"
echo "  FAILED: $TESTS_FAILED"

# Match the RESULTS: line format the parallel test runner expects.
TESTS_RUN=$((TESTS_PASSED + TESTS_FAILED))
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"

[[ $TESTS_FAILED -eq 0 ]]
