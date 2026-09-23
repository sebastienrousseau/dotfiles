#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Coverage for the two scripts/dot/commands/agent.sh checkpoint arms the
# meta-driven suites cannot reach: `checkpoint list` without jq (cmd_mode's
# dependency check demands jq first, so the module is sourced and that check
# is stubbed), and `checkpoint replay` of a checkpoint whose argv is empty.
# State lives in a mktemp XDG tree; the real agent-profiles.json is only read.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/agent-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" XDG_STATE_HOME="$WORK/state" XDG_CONFIG_HOME="$WORK/home/.config"
export AGENT_PROFILE_CONFIG="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"
export AGENT_STATE_FILE="$WORK/agent-mode.env" NO_COLOR=1 DOTFILES_SHOW_LOGO=0
mkdir -p "$HOME" "$XDG_STATE_HOME/dotfiles/checkpoints"
printf 'DOT_AGENT_PROFILE=ask\n' >"$AGENT_STATE_FILE"

# agent <path> <args…> — source the module and run cmd_mode with that PATH.
agent() {
  local path="$1"
  shift
  PATH="$path" "$REAL_BASH" -c '
    source "$1/lib/dot/utils.sh"
    source "$1/lib/dot/log.sh"
    source "$1/scripts/dot/commands/agent.sh"
    _agent_assert_dependencies() { :; }
    shift
    cmd_mode "$@"
  ' _ "$REPO_ROOT" "$@" 2>&1
}

NOJQ="$WORK/nojq"
mkdir -p "$NOJQ"
for c in sed tail find sort cat date mkdir dirname basename head tr uname; do
  p="$(command -v "$c" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOJQ/$c"
done

test_start "checkpoint_list_without_jq_prints_raw_json"
printf '{"id":"raw1","profile":"ask"}\n' >"$XDG_STATE_HOME/dotfiles/checkpoints/raw1.json"
out="$(agent "$NOJQ" checkpoint list 5)"
assert_contains '{"id":"raw1","profile":"ask"}' "$out" "raw checkpoint JSON is printed"
assert_output_not_contains "Agent Checkpoints" "printf '%s' '$out'"

test_start "checkpoint_replay_refuses_an_empty_argv"
if command -v jq >/dev/null 2>&1; then
  printf '{"id":"empty1","profile":"ask","argv":[]}\n' >"$XDG_STATE_HOME/dotfiles/checkpoints/empty1.json"
  out="$(agent "$PATH" checkpoint replay empty1)"
  assert_contains "Checkpoint has no replayable command: empty1" "$out" "empty argv refused"
else
  echo "  jq not installed — replay case skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
