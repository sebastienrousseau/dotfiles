#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# `dot system clean [--caches] [--yes]` (P9, plugins/system/libexec/system/
# clean.sh): reports the build caches, prunes each with its own tool scoped
# to its directory, skips a tool that is not installed, fails when a prune
# fails, and only reports when there is no terminal to ask.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ENTRY="$REPO_ROOT/plugins/system/dot-system"
# The caller's own cache variables (mise sets them) must not leak in.
unset UV_CACHE_DIR PIP_CACHE_DIR GOCACHE
WORK="$(mktemp -d "${TMPDIR:-/tmp}/clean-caches.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# A PATH holding every system tool except the cache tools, so which of uv,
# pip3, python3 and go is "installed" is decided by each test alone.
SYSBIN="$WORK/sysbin"
mkdir -p "$SYSBIN"
for tool in /usr/bin/* /bin/*; do
  name="${tool##*/}"
  case "$name" in uv | pip | pip3 | python3 | python3.* | go | gofmt) continue ;; esac
  [[ -e "$SYSBIN/$name" ]] || ln -s "$tool" "$SYSBIN/$name"
done
ln -sf "$BASH" "$SYSBIN/bash"

# fake_tool DIR NAME RC: a NAME that logs its argv and cache variables to
# $WORK/calls.log, then exits RC.
fake_tool() {
  mkdir -p "$1"
  cat >"$1/$2" <<EOF
#!/usr/bin/env bash
printf '%s %s uv=%s pip=%s go=%s\n' "$2" "\$*" "\${UV_CACHE_DIR:-}" "\${PIP_CACHE_DIR:-}" "\${GOCACHE:-}" >>"$WORK/calls.log"
exit $3
EOF
  chmod +x "$1/$2"
}

# run_clean FAKEBIN ARGS...: run `dot system clean ARGS` in a sandbox whose
# build root holds a 64 KiB file in each cache; output in $OUT, rc in $RC.
run_clean() {
  local fakebin="$1"
  shift
  rm -rf "${WORK:?}/home" "${WORK:?}/calls.log"
  mkdir -p "$WORK/home/state/dot"
  for c in uv pip go; do
    mkdir -p "$WORK/home/builds/$c-cache"
    head -c 65536 /dev/zero >"$WORK/home/builds/$c-cache/blob"
  done
  printf '1 2 x\n' >"$WORK/home/state/dot/build-cache-kb"
  RC=0
  OUT="$(HOME="$WORK/home" XDG_STATE_HOME="$WORK/home/state" \
    DOT_BUILD_ROOT="$WORK/home/builds" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
    PATH="$fakebin:$SYSBIN" bash "$ENTRY" clean "$@" </dev/null 2>&1)" || RC=$?
}

calls() { cat "$WORK/calls.log" 2>/dev/null; }

test_start "no_terminal_and_no_yes_only_reports"
fake_tool "$WORK/all" uv 0
fake_tool "$WORK/all" pip3 0
fake_tool "$WORK/all" go 0
run_clean "$WORK/all" --caches
assert_equals "0||yes" "$RC|$(calls)|$([[ -s "$WORK/home/state/dot/build-cache-kb" ]] && echo yes)" \
  "nothing is pruned and the recorded size stays"
assert_contains "Report only" "$OUT" "it says why it only reported"
assert_contains "uv-cache" "$OUT" "each cache's size is shown"

test_start "yes_prunes_each_cache_scoped_to_its_dir"
run_clean "$WORK/all" --caches --yes
B="$WORK/home/builds"
assert_equals "0" "$RC" "every prune succeeded"
assert_contains "uv cache prune uv=$B/uv-cache pip= go=" "$(calls)" "uv prunes only UV_CACHE_DIR"
assert_contains "pip3 cache purge uv= pip=$B/pip-cache go=" "$(calls)" "pip3 purges only PIP_CACHE_DIR"
assert_contains "go clean -cache uv= pip= go=$B/go-cache" "$(calls)" "go cleans only GOCACHE"
assert_equals "no" "$([[ -e "$WORK/home/state/dot/build-cache-kb" ]] && echo yes || echo no)" \
  "the stale recorded size is removed for doctor to measure again"
assert_contains "Reclaimed" "$OUT" "the reclaimed total is reported"

test_start "short_yes_flag_is_accepted"
run_clean "$WORK/all" -y
assert_equals "0|3" "$RC|$(calls | wc -l | tr -d ' ')" "-y prunes like --yes"

test_start "pip_falls_back_to_python3_m_pip"
fake_tool "$WORK/py" python3 0
run_clean "$WORK/py" --yes
assert_contains "python3 -m pip cache purge uv= pip=$WORK/home/builds/pip-cache" "$(calls)" \
  "without pip3, python3 -m pip purges the pip cache"
assert_contains "uv-cache" "$OUT" "uv is reported"
assert_contains "skipped: uv is not installed" "$OUT" "a missing uv is skipped, not an error"
assert_contains "skipped: go is not installed" "$OUT" "a missing go is skipped, not an error"
assert_equals "0" "$RC" "skipping is success"

test_start "no_pip_at_all_is_skipped"
mkdir -p "$WORK/none"
run_clean "$WORK/none" --yes
assert_equals "0|" "$RC|$(calls)" "no tool runs"
assert_contains "skipped: pip is not installed" "$OUT" "neither pip3 nor python3 means skipped"

test_start "a_failed_prune_fails_the_command"
fake_tool "$WORK/gofail" uv 0
fake_tool "$WORK/gofail" pip3 0
fake_tool "$WORK/gofail" go 3
run_clean "$WORK/gofail" --yes
assert_equals "1" "$RC" "one failed prune makes the command fail"
assert_contains "'go clean -cache' failed" "$OUT" "the failing command is named"
assert_contains "uv cache prune" "$(calls)" "the other caches are still pruned"

test_start "a_missing_cache_dir_is_left_alone"
run_clean "$WORK/all" --yes
rm -rf "$WORK/home/builds/go-cache" "$WORK/calls.log"
RC=0
OUT="$(HOME="$WORK/home" XDG_STATE_HOME="$WORK/home/state" DOT_BUILD_ROOT="$WORK/home/builds" \
  DOTFILES_NONINTERACTIVE=1 PATH="$WORK/all:$SYSBIN" bash "$ENTRY" clean --yes </dev/null 2>&1)" || RC=$?
assert_equals "0|no" "$RC|$(calls | grep -q '^go ' && echo yes || echo no)" "go is not run for a cache that does not exist"

test_start "unknown_flag_is_a_usage_error"
run_clean "$WORK/all" --bogus
assert_equals "64|" "$RC|$(calls)" "an unknown flag exits 64 before anything runs"
assert_contains "unknown flag '--bogus'" "$OUT" "the flag is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
