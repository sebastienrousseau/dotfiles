#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression: `dot <cmd> --help` and `dot <cmd> -h` MUST short-circuit
# to `dot help <cmd>` for EVERY registered top-level command, and for
# every documented two-word subcommand — WITHOUT triggering any of
# the state-mutating side effects that pre-audit made this class of
# bug so dangerous.
#
# Regression baseline: commit fix/dot-command-bugs — the 2026-07-05
# audit found ~22 commands treating `--help` as data:
#   - `dot ai delegate --help` invoked the Vibe CLI with prompt
#     "--help" (SPENT MONEY on the LLM roundtrip).
#   - `dot edit --help` opened $EDITOR and blocked on TTY.
#   - `dot upgrade --help` ran the real upgrade including git pulls
#     and a full nvim + lazy plugin sync — timed out at 60s+.
#   - `dot sandbox --help` built a Docker sandbox image (~ 300 MB).
#   - `dot backup --help` created a real ~1 GB tar of $HOME.
#   - `dot secrets set --help` treated `--help` as the secret key
#     and blocked reading the secret value from stdin.
#   - many more (see the fix/dot-command-bugs commit message for
#     the full list).
#
# Fix: universal intercept in bin/dot BEFORE any dispatch, delegating
# `<cmd> --help` and `<cmd> -h` to `dot help <cmd>`.
#
# Assertions per command:
#   1. Exit code 0 (help is always successful).
#   2. Stdout NOT EMPTY — help renderer produced something.
#   3. Stdout contains the command name — the delegated `dot help
#      <cmd>` printed help for the RIGHT command.
#   4. No side-effect signatures in stderr: no editor spawn attempts
#      (`vim`, `nvim`, `nano`, `code`), no docker builds, no
#      chezmoi apply, no LLM API roundtrip.
#   5. Filesystem invariant: SANDBOX_STATE_BEFORE == SANDBOX_STATE_AFTER
#      (no new files, no modifications). This is the anti-mutation
#      guarantee.
#
# Runs under a completed sandboxed HOME so incidental writes land in
# tmp and don't leak into the developer's environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

# ═══════════════════════════════════════════════════════════════
# Sandbox HOME. Reset before every command so filesystem-mutation
# assertions catch even the tiniest speculative write.
# ═══════════════════════════════════════════════════════════════

sandbox_root="$(mktemp -d -t dot-help.XXXXXX)"
trap 'rm -rf "$sandbox_root"' EXIT

reset_sandbox() {
  local sub
  sub="$(mktemp -d "$sandbox_root/home.XXXXXX")"
  mkdir -p "$sub/.config" "$sub/.local/share" "$sub/.cache" \
    "$sub/.local/state"
  ln -s "$REPO_ROOT" "$sub/.dotfiles"
  printf '%s\n' "$sub"
}

# Snapshot the shape of a directory tree so we can diff it after a
# command runs. We hash file paths + sizes rather than mtimes so we
# don't false-positive on ls-time updates.
#
# stat's format flag differs across platforms: GNU (Linux) uses
# `-c '%n %s'`, BSD/macOS uses `-f '%N %z'`. Probe once so this runs
# on Linux CI too — the old BSD-only form exited non-zero under xargs
# (rc=123) and, via `set -e`, aborted before the RESULTS: line.
if stat -c '%s' . >/dev/null 2>&1; then
  _STAT_FMT=(stat -c '%n %s') # GNU coreutils
else
  _STAT_FMT=(stat -f '%N %z') # BSD / macOS
fi
sandbox_snapshot() {
  local root="$1"
  find "$root" -type f -print0 2>/dev/null \
    | xargs -0 "${_STAT_FMT[@]}" 2>/dev/null \
    | sort
}

# ═══════════════════════════════════════════════════════════════
# Enumerate every route from bin/dot's route table.
# ═══════════════════════════════════════════════════════════════

routes=()
while IFS='|' read -r cmd _; do
  # Skip flag aliases (`--help`, `-h`, `--version`, `-v`) which are
  # not user-facing commands.
  case "$cmd" in
    --*|-*) continue ;;
  esac
  routes+=("$cmd")
done < <(
  awk '/^_dot_command_routes\(\)/{flag=1; next}
       flag && /^EOF$/{exit}
       flag && /^[a-z][a-z_-]+\|/{print}' "$DOT_CLI"
)

test_start "route_table_has_commands"
if [[ ${#routes[@]} -ge 30 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ${#routes[@]} commands in route table"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only ${#routes[@]} commands — parser broken?"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

# Hidden aliases and sub-dispatchers that don't have their own
# help entry — `dot help <alias>` returns "Unknown help topic".
# The universal --help intercept still fires (so no side effects),
# but rc=1 from the delegated help is legitimate. This list mirrors
# test_dot_subcommand_smoke.sh's HIDDEN_FROM_HELP.
readonly -a HIDDEN_FROM_HELP=(
  # Aliases / alternate names for already-documented commands
  apply update scorecard attestation security-score
  # Health subroutines reachable through `dot doctor` or `dot health`
  health health-check smoke-test heal drift intelligence
  # Internal command-routing topics
  conflicts locks log-rotate alias-check setup setup-mode
  # AI-related sub-dispatchers that operate purely on routing
  load-bench-pty
  # Sub-dispatcher modules that print their own help when invoked
  agents init registry manual patterns
)

is_hidden_alias() {
  local needle="$1"
  local h
  for h in "${HIDDEN_FROM_HELP[@]}"; do
    [[ "$h" == "$needle" ]] && return 0
  done
  return 1
}

# Two-word subcommands surfaced by the audit. Each must ALSO be safe
# under `--help` even though the second word isn't a registered
# top-level command — the intercept in bin/dot fires on the first
# word and delegates to `dot help <first>`, which is the correct
# canonical help for the whole subcommand namespace.
#
# We test them separately because the intercept behaviour on
# multi-word arg lists is critical to keep verified — a future
# reorg could easily break this.
readonly -a TWO_WORD_SUBCOMMANDS=(
  "secrets set"
  "secrets get"
  "secrets load"
  "secrets edit"
  "mode run"
  "agent checkpoint"
  "agent delegate"
  "fleet enforce"
  "wallpaper rotate"
  "ai chat"
  "ai serve"
  "ai delegate"
  "ai ask"
  "ai tools"
)

# ═══════════════════════════════════════════════════════════════
# Patterns that MUST NOT appear in stderr under --help. Each
# indicates a specific class of side effect the audit found.
# ═══════════════════════════════════════════════════════════════

readonly -a FORBIDDEN_STDERR_PATTERNS=(
  # Editor spawn attempts (edit / patterns edit / secrets edit).
  "requires TTY"
  "opening in editor"
  "waiting for editor"
  # Docker build attempts (sandbox --help).
  "Building sandbox"
  "docker build"
  # Chezmoi apply attempts (upgrade --help, sync --help).
  "chezmoi apply"
  "Applying dotfiles"
  # AI provider roundtrips (ai delegate --help pre-fix spent money).
  "Executing.*with pattern"
  "vibe delegate"
  "openai.*api"
  # Signature classes the previous audit turned up.
  "Invalid SSH target"
  "SSH key not found"
  "Secret not found"
  "History file not found"
  "not a valid command"
  "Unknown flag"
  # Argument parsing gone wrong (dirname: illegal option).
  "illegal option"
  # The "command not found" surface — usually indicates that --help
  # was passed to an inner exec.
  "command not found"
)

# ═══════════════════════════════════════════════════════════════
# Runner: assert --help on <cmd> is safe + informative.
# ═══════════════════════════════════════════════════════════════

check_help_flag_safe() {
  local cmd="$1"          # command as space-separated argv
  local flag="$2"         # `--help` or `-h`
  local test_name
  test_name="$(echo "${cmd}_${flag}" | tr ' -/' '___')"
  test_start "help_flag_safe_${test_name}"

  local sandbox
  sandbox="$(reset_sandbox)"
  local before_snap after_snap
  before_snap="$(sandbox_snapshot "$sandbox")"

  local stdout_file stderr_file exit_code
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  # shellcheck disable=SC2064
  trap "rm -f $stdout_file $stderr_file" RETURN

  # shellcheck disable=SC2086
  HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    timeout 10 bash "$DOT_CLI" $cmd "$flag" \
    >"$stdout_file" 2>"$stderr_file" \
    && exit_code=0 || exit_code=$?

  after_snap="$(sandbox_snapshot "$sandbox")"

  local failure_reasons=()
  local first_word
  first_word="${cmd%% *}"

  # ── Assertion 1: rc=0 (help is always successful).
  # Hidden aliases delegate to `dot help <alias>` which returns
  # "Unknown help topic" with rc=1 — that's legitimate because the
  # alias's real help is under a different command. We still assert
  # NO side effect happened, just relax the rc check.
  if [[ $exit_code -ne 0 ]] && ! is_hidden_alias "$first_word"; then
    failure_reasons+=("exit code=$exit_code (expected 0 for public commands)")
  fi

  # ── Assertion 2: stdout non-empty (or stderr for the
  # "Unknown help topic" case for hidden aliases).
  if [[ ! -s "$stdout_file" && ! -s "$stderr_file" ]]; then
    failure_reasons+=("stdout and stderr both empty — nothing rendered")
  fi

  # ── Assertion 3: stdout contains the command name (skip for
  # hidden aliases whose delegated help is an "Unknown topic" error).
  if ! is_hidden_alias "$first_word" \
      && ! grep -q -w -F "$first_word" "$stdout_file"; then
    failure_reasons+=("stdout does not mention '$first_word' — wrong command's help emitted")
  fi

  # ── Assertion 4: no forbidden side-effect pattern in stderr.
  local pattern
  for pattern in "${FORBIDDEN_STDERR_PATTERNS[@]}"; do
    if grep -q -E "$pattern" "$stderr_file"; then
      failure_reasons+=("stderr contains side-effect pattern: '$pattern'")
    fi
  done

  # ── Assertion 5: sandbox filesystem unchanged.
  if [[ "$before_snap" != "$after_snap" ]]; then
    local diff_lines
    diff_lines="$(diff <(printf '%s' "$before_snap") <(printf '%s' "$after_snap") | head -5)"
    failure_reasons+=("sandbox filesystem mutated (--help should be side-effect free):")
    failure_reasons+=("$diff_lines")
  fi

  if [[ ${#failure_reasons[@]} -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
    local r
    for r in "${failure_reasons[@]}"; do
      printf '        %s\n' "$r"
    done
    if [[ -s "$stderr_file" ]]; then
      printf '        stderr (first 3 lines):\n'
      head -3 "$stderr_file" | sed 's/^/          /'
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════
# Run the matrix — every route × { --help, -h } + two-word cases
# ═══════════════════════════════════════════════════════════════

echo
echo "── Universal --help safety regression ──"
echo "── Testing $(( ${#routes[@]} * 2 + ${#TWO_WORD_SUBCOMMANDS[@]} * 2 )) invocations across ${#routes[@]} routes + ${#TWO_WORD_SUBCOMMANDS[@]} two-word subcommands ──"
echo

# Every top-level command under both flag variants.
for r in "${routes[@]}"; do
  # `help` itself is exempt: `dot help --help` short-circuits to
  # `dot help`, which is not a per-command topic. The universal
  # intercept skips route=="help" for that reason.
  [[ "$r" == "help" ]] && continue
  # `search` is exempt: it searches for its arg literally, including
  # the string "--help" if a user chose to (surreal but supported).
  [[ "$r" == "search" ]] && continue
  check_help_flag_safe "$r" "--help"
  check_help_flag_safe "$r" "-h"
done

# Two-word subcommands under both flag variants.
for pair in "${TWO_WORD_SUBCOMMANDS[@]}"; do
  check_help_flag_safe "$pair" "--help"
  check_help_flag_safe "$pair" "-h"
done

# ═══════════════════════════════════════════════════════════════
# Explicit "must NOT run" spot checks — dangerous side effects
# that pre-audit made this bug so painful. These use `-h` (the
# shorter alias) to guard against a future regression that only
# fixes `--help` but leaves `-h` broken.
# ═══════════════════════════════════════════════════════════════

test_start "help_flag_ai_delegate_does_not_spend_money"
sandbox="$(reset_sandbox)"
# `dot ai delegate -h` pre-fix invoked the Vibe CLI with prompt "-h".
# The forbidden-pattern check above should catch it, but we assert
# a separate spot check because this is the highest-stakes
# regression: it costs real money and the class of bug is easy to
# reintroduce.
out="$(HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    timeout 5 bash "$DOT_CLI" ai delegate -h 2>&1)"
if echo "$out" | grep -qE 'delegate|vibe|Executing.*pattern|api\.openai|api\.anthropic'; then
  # If the delegate was actually invoked, we'd see those markers.
  # Presence == regression.
  if echo "$out" | grep -qE 'Executing.*with pattern|Sending.*to |POST /v1/'; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ai delegate side-effect markers observed"
  else
    # The word "delegate" appearing in help text is fine — the
    # command's own name. Same for "vibe". What we're guarding
    # against is the ACTUAL invocation.
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "help_flag_edit_does_not_spawn_editor"
sandbox="$(reset_sandbox)"
# `dot edit -h` pre-fix opened $EDITOR and blocked on TTY. If the
# intercept regresses, the 5s timeout will kill the process — rc
# will be non-zero.
if HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    EDITOR=/bin/false \
    timeout 5 bash "$DOT_CLI" edit -h >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot edit -h did NOT short-circuit (blocked or errored)"
fi

test_start "help_flag_upgrade_does_not_run_chezmoi_apply"
sandbox="$(reset_sandbox)"
# `dot upgrade -h` pre-fix ran the real upgrade including git pulls
# and nvim spawn. Same 5s timeout guarantee.
if HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    timeout 5 bash "$DOT_CLI" upgrade -h >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot upgrade -h did NOT short-circuit"
fi

test_start "help_flag_backup_does_not_tar_home"
sandbox="$(reset_sandbox)"
# `dot backup -h` pre-fix ran the real tar. If the intercept
# regresses, the sandbox would be scanned by tar (could take
# a long time on a real $HOME). 5s timeout catches it.
if HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    timeout 5 bash "$DOT_CLI" backup -h >/dev/null 2>&1; then
  # Additional check: no .tar files created anywhere in the sandbox.
  if find "$sandbox" -name '*.tar*' -type f 2>/dev/null | grep -q .; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: tar archive created in sandbox"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  fi
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot backup -h did NOT short-circuit"
fi

test_start "help_flag_sandbox_does_not_docker_build"
sandbox="$(reset_sandbox)"
# `dot sandbox -h` pre-fix ran a real docker build. Under 5s timeout
# a real build would either fail (Docker not present on this
# workstation) or take much longer than 5s. Either way,
# short-circuit must NOT invoke docker.
if HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    timeout 5 bash "$DOT_CLI" sandbox -h >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot sandbox -h did NOT short-circuit"
fi

# ═══════════════════════════════════════════════════════════════
# `--` sentinel must NOT trigger the help intercept — verifies the
# scanner correctly stops at end-of-options.
# ═══════════════════════════════════════════════════════════════

test_start "help_flag_after_double_dash_is_literal_arg"
sandbox="$(reset_sandbox)"
# `dot search -- --help` should search for the literal string
# "--help", not delegate to `dot help search`. This verifies the
# `--` sentinel behavior in _has_help_flag.
out="$(HOME="$sandbox" \
    XDG_CONFIG_HOME="$sandbox/.config" \
    XDG_DATA_HOME="$sandbox/.local/share" \
    XDG_CACHE_HOME="$sandbox/.cache" \
    XDG_STATE_HOME="$sandbox/.local/state" \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    timeout 5 bash "$DOT_CLI" search -- --help 2>&1)" || true
# `dot search` treats its arg as a keyword; either way (found or
# not-found), it should not print the canonical `dot help` topic
# for search. The presence of "Reference" / "Dotfiles Command
# Reference" would indicate the intercept incorrectly fired.
if echo "$out" | grep -q 'Dotfiles Command Reference'; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -- sentinel didn't prevent help intercept"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

echo
echo "── Summary ──"
echo "  RUN:    $((TESTS_PASSED + TESTS_FAILED))"
echo "  PASSED: $TESTS_PASSED"
echo "  FAILED: $TESTS_FAILED"

TESTS_RUN=$((TESTS_PASSED + TESTS_FAILED))
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"

[[ $TESTS_FAILED -eq 0 ]]
