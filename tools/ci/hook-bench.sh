#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# tools/ci/hook-bench.sh: p95 gate for the agent hook.
#
# Claude Code, Gemini CLI and Codex run `dot cli hook run` on every prompt,
# tool call and stop, so its cost multiplies by every tool call of every
# agent. This runs N events through bin/dot exactly as an agent's hook does
# (payload on stdin, a sandboxed state dir), and exits 1 when the 95th
# percentile is over the budget.
#
# Usage:
#   bash tools/ci/hook-bench.sh [--budget-ms <n>] [--runs <n>]
#
# Env overrides:
#   DOT_HOOK_BENCH_BUDGET_MS  p95 budget in ms (default: 30).
#   DOT_HOOK_BENCH_RUNS       Events to time (default: 100).
#
# Needs bash 5 ($EPOCHREALTIME); the hook itself runs under the first bash on
# PATH, as an agent would start it.

set -euo pipefail

BUDGET_MS="${DOT_HOOK_BENCH_BUDGET_MS:-30}"
RUNS="${DOT_HOOK_BENCH_RUNS:-100}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget-ms)
      BUDGET_MS="$2"
      shift 2
      ;;
    --runs)
      RUNS="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '5,21p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${EPOCHREALTIME:-}" ]]; then
  echo "::error::hook-bench needs bash 5 (\$EPOCHREALTIME); this is $BASH_VERSION" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/hook-bench.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# _us: the wall clock in microseconds.
_us() { local t="${EPOCHREALTIME/[.,]/}" && printf '%s' "$((10#$t))"; }

events=(UserPromptSubmit PreToolUse PostToolUse Notification Stop)
samples=()
# One untimed run: the first exec pays for loading bash and jq from disk.
printf '{"session_id":"warm","hook_event_name":"Stop"}' |
  XDG_STATE_HOME="$WORK" bash "$REPO_ROOT/bin/dot" cli hook run --agent claude
for ((i = 0; i < RUNS; i++)); do
  payload="{\"session_id\":\"bench-$((i % 4))\",\"hook_event_name\":\"${events[i % 5]}\",\"cwd\":\"$REPO_ROOT\",\"tool_name\":\"Bash\"}"
  start="$(_us)"
  printf '%s' "$payload" | XDG_STATE_HOME="$WORK" bash "$REPO_ROOT/bin/dot" cli hook run --agent claude
  end="$(_us)"
  samples+=("$(((end - start) / 1000))")
done

sorted="$(printf '%s\n' "${samples[@]}" | sort -n)"
p50="$(sed -n "$(((RUNS + 1) / 2))p" <<<"$sorted")"
p95="$(sed -n "$(((RUNS * 95 + 99) / 100))p" <<<"$sorted")"
echo "agent hook: $RUNS events  p50 ${p50}ms  p95 ${p95}ms  budget ${BUDGET_MS}ms"
[[ -s "$WORK/dot/cli/agents/claude/bench-0.json" ]] || {
  echo "::error::the hook wrote no state file; the timings measure nothing" >&2
  exit 1
}

if ((p95 > BUDGET_MS)); then
  echo "::error::agent hook p95 ${p95}ms > budget ${BUDGET_MS}ms" >&2
  echo "  Every agent tool call pays this twice (PreToolUse, PostToolUse)." >&2
  echo "  Look for a fork added to plugins/cli/libexec/hook.sh or to the" >&2
  echo "  fast path at the top of bin/dot." >&2
  exit 1
fi
echo "✓ agent hook within budget"
