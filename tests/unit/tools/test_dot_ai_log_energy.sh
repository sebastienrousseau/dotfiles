#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# defaults/dot_local/bin/executable_dot-ai-log records a run in
# dotfiles-ai.db. Energy is not measured anywhere, so joules and gco2eq are
# stored as NULL rather than estimated from the run's duration (plan v3, T0).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LOGGER="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-log"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-log.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

test_start "a_run_is_logged_without_invented_energy"
if command -v python3 >/dev/null 2>&1 && command -v sqlite3 >/dev/null 2>&1; then
  rc=0
  HOME="$WORK" XDG_DATA_HOME="$WORK/data" DOT_AI_LOG_FORCE_PYTHON=1 \
    python3 "$LOGGER" claude dotfiles 0 12.5 40 2026-10-22T12:00:00Z >/dev/null 2>&1 || rc=$?
  assert_equals "0" "$rc" "the logger exits 0"
  row="$(sqlite3 -batch -init /dev/null -list -separator "|" "$WORK/data/dotfiles-ai.db" \
    "SELECT delegate, duration_secs, prompt_words, joules IS NULL, gco2eq IS NULL FROM runs;")"
  assert_equals "claude|12.5|40|1|1" "$row" "the measured fields are kept and energy is NULL"
else
  printf '  - skipped: python3 or sqlite3 not installed\n'
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
