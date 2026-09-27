#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# dot perf's scoring and reporting at exact boundaries. Time is a counter:
# python3's `import time` one-liners print it and each stub shell advances
# it by its configured startup cost (ZSH_MS, BASH_MS), so every measured
# mean is exact. Other python3 calls go to the real interpreter.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PERF="$REPO_ROOT/scripts/diagnostics/perf.sh"
REAL_BASH="$(command -v bash)"
REAL_PY="$(command -v python3)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# perf "<shells>" [VAR=value...] -- [args]: sets OUT and RC.
perf() {
  local shells="$1" t d="$WORK/case"
  shift
  rm -rf "$d" && mkdir -p "$d/home" "$d/stubs" "$d/tools"
  # Only these tools: no real zsh/bash/fish on PATH to be discovered.
  for t in cat tr seq dirname basename date mkdir rm head tail sed awk grep env sort cut wc uname stat mktemp locale tee; do
    p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$d/tools/$t"
  done
  echo 1000 >"$d/clock" && echo 0 >"$d/pending"
  cat >"$d/stubs/python3" <<PY
#!$REAL_BASH
if [ "\${1:-}" = -c ] && [ "\${2#*import time}" != "\$2" ]; then
  c=\$((\$(cat "$d/clock") + \$(cat "$d/pending"))); echo "\$c" >"$d/clock"; echo 0 >"$d/pending"; echo "\$c"; exit 0
fi
exec "$REAL_PY" "\$@"
PY
  for t in $shells; do
    cat >"$d/stubs/$t" <<SH
#!$REAL_BASH
var=\$(printf '%s' "$t" | tr '[:lower:]' '[:upper:]')_MS
eval "echo \\\${\$var:-50}" >"$d/pending"
SH
  done
  chmod +x "$d/stubs"/*
  local -a envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    envs+=("$1")
    shift
  done
  [[ $# -gt 0 ]] && shift
  RC=0
  OUT="$(env -i HOME="$d/home" XDG_CACHE_HOME="$d/home/.cache" XDG_STATE_HOME="$d/home/.state" \
    PATH="$d/stubs:$d/tools" TERM=dumb NO_COLOR=1 ${envs[@]+"${envs[@]}"} \
    "$REAL_BASH" "$PERF" --no-baseline-check -r 1 "$@" </dev/null 2>&1)" || RC=$?
}
json() { printf '%s\n' "$OUT" | "$REAL_PY" -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

test_start "perf_mean_equal_to_target_passes"
perf zsh ZSH_MS=250 -- --json
assert_equals "0:250:True" "$RC:$(json 'd["mean_ms"]'):$(json 'd["shells"]["zsh"]["pass"]')" \
  "a mean exactly at the target is a pass"

test_start "perf_mean_one_over_target_fails"
perf zsh ZSH_MS=251 -- --json
assert_equals "False" "$(json 'd["shells"]["zsh"]["pass"]')" "one ms over is a fail"

test_start "perf_score_uses_the_zsh_mean"
perf "zsh bash" ZSH_MS=200 BASH_MS=40 -- --json
assert_equals "200" "$(json 'd["mean_ms"]')" "zsh is the reference shell"

test_start "perf_score_falls_back_to_the_first_shell_without_zsh"
perf "bash fish" BASH_MS=80 FISH_MS=150 -- --json
assert_equals "80" "$(json 'd["mean_ms"]')" "bash, the first measured shell"

test_start "perf_json_has_no_regressions_key_without_regressions"
perf zsh ZSH_MS=100 -- --json
assert_equals "no:0" "$(json '"yes" if "regressions" in d else "no"'):$(json 'd["regression_count"]')" \
  "an empty regressions list is omitted"

test_start "perf_score_of_exactly_80_is_good"
perf zsh ZSH_MS=400
assert_contains "Good (tune to reach 100)" "$OUT" "score 80 is still good"

test_start "perf_score_of_79_needs_attention"
perf zsh ZSH_MS=408
assert_contains "Needs attention" "$OUT" "score 79 needs attention"

test_start "perf_score_is_100_at_the_target"
perf zsh ZSH_MS=250 -- --json
assert_equals "100" "$(json 'd["score"]')" "at target scores 100"

test_start "perf_score_is_0_at_the_ceiling"
perf zsh ZSH_MS=1000 -- --json
assert_equals "0" "$(json 'd["score"]')" "at DOTFILES_PERF_MAX_MS scores 0"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
