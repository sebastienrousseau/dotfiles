#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# `dot system clean --caches` prunes the private build caches below
# DOT_BUILD_ROOT with each tool's own command, scoped to that directory
# (P9), asks first and only reports without a terminal; doctor warns when
# they grow past DOT_BUILD_CACHE_WARN_GB. Everything runs under `env -i`
# in a scratch HOME with stub uv, pip3 and go: the real caches (whose
# variables a developer shell exports) are never named, let alone pruned.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/host_path.sh"

BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-clean.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SYS="$(host_path_without "$WORK/sys" uv pip pip3 python3 go)"
ROOT="$WORK/home/.cache/dot/builds"
mkdir -p "$WORK/stubs" "$WORK/home"

# stub NAME VAR: NAME logs "NAME args VAR=<value>" and empties the cache
# directory VAR names, as its real prune would.
stub() {
  cat >"$WORK/stubs/$1" <<EOF
#!$BASH_BIN
printf '%s\n' "$1 \$* $2=\${$2:-}" >>"$WORK/calls"
[ -n "\${$2:-}" ] && [ -d "\${$2}" ] && find "\${$2}" -mindepth 1 -delete
exit 0
EOF
  chmod +x "$WORK/stubs/$1"
}
stub uv UV_CACHE_DIR
stub pip3 PIP_CACHE_DIR
stub go GOCACHE

# fill: a megabyte in each cache, and one outside the root.
fill() {
  local d
  for d in uv-cache pip-cache go-cache; do
    mkdir -p "$ROOT/$d"
    head -c 1048576 /dev/zero >"$ROOT/$d/blob"
  done
  mkdir -p "$WORK/elsewhere"
  printf 'keep\n' >"$WORK/elsewhere/blob"
  : >"$WORK/calls"
}

# dot ARGS...: the CLI in the scratch HOME with nothing inherited.
dot() {
  RC=0
  OUT="$(env -i HOME="$WORK/home" PATH="$WORK/stubs:$SYS" TERM=dumb NO_COLOR=1 \
    UV_CACHE_DIR="$WORK/elsewhere" GOCACHE="$WORK/elsewhere" PIP_CACHE_DIR="$WORK/elsewhere" \
    "$BASH_BIN" "$REPO_ROOT/bin/dot" "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "without_a_terminal_it_only_reports"
fill
dot system clean --caches
assert_equals "0" "$RC" "exits 0"
assert_contains "uv-cache" "$OUT" "lists each cache"
assert_contains "Report only" "$OUT" "says it only reported"
assert_equals "" "$(cat "$WORK/calls")" "runs no prune"
assert_file_exists "$ROOT/uv-cache/blob" "and deletes nothing"

test_start "yes_prunes_each_cache_with_its_own_tool_scoped_to_the_root"
fill
dot system clean --caches --yes
assert_equals "0" "$RC" "exits 0"
assert_contains "uv cache prune UV_CACHE_DIR=$ROOT/uv-cache" "$(cat "$WORK/calls")" "uv, on its cache under the root"
assert_contains "pip3 cache purge PIP_CACHE_DIR=$ROOT/pip-cache" "$(cat "$WORK/calls")" "pip, on its cache under the root"
assert_contains "go clean -cache GOCACHE=$ROOT/go-cache" "$(cat "$WORK/calls")" "go, on its cache under the root"
assert_file_not_exists "$ROOT/uv-cache/blob" "the caches are pruned"
assert_file_exists "$WORK/elsewhere/blob" "a cache the environment points elsewhere is untouched"
assert_contains "Reclaimed" "$OUT" "and it says how much"

test_start "a_bad_flag_is_a_usage_error"
dot system clean --everything
assert_equals "64" "$RC" "exits 64"

# sdk FN [GB] [PATH]: run an sdk.sh function in the sandboxed home.
sdk() {
  env -i HOME="$WORK/home" PATH="${3:-$SYS}" NO_COLOR=1 DOT_BUILD_CACHE_WARN_GB="${2:-10}" "$BASH_BIN" -c \
    'source "$1/lib/dot/sdk.sh"; '"$1" _ "$REPO_ROOT" 2>&1
}
STAMP="$WORK/home/.local/state/dot/build-cache-kb"

test_start "doctor_warns_past_the_threshold"
fill
sdk dot_build_cache_refresh >/dev/null
assert_file_exists "$STAMP" "a measurement is recorded"
assert_contains "dot system clean --caches" "$(sdk dot_build_cache_warn 0)" "over the limit: warns with the fix"
assert_equals "" "$(sdk dot_build_cache_warn 10)" "under it: silent"

# Sizing a large cache walks every file (25 GB took over 20 s); dot doctor
# must not wait for it. The warning reads the recorded measurement, and a
# missing or day-old one is refreshed in the background.
test_start "doctor_never_measures_in_the_foreground"
rm -f "$STAMP"
mkdir -p "$WORK/slow"
printf '#!/bin/sh\nsleep 3\necho "4 $2"\n' >"$WORK/slow/du"
chmod +x "$WORK/slow/du"
start=$SECONDS
out="$(sdk dot_build_cache_warn 0 "$WORK/slow:$SYS")"
assert_true "(( SECONDS - start < 3 ))" "the warning returns without waiting for du"
assert_equals "" "$out" "with nothing recorded yet it stays silent"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -s "$STAMP" ]] && break
  sleep 1
done
assert_file_exists "$STAMP" "and the background refresh records a measurement"

test_start "pruning_forgets_the_measurement"
fill
sdk dot_build_cache_refresh >/dev/null
dot system clean --caches --yes
assert_file_not_exists "$STAMP" "the next doctor measures again"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
