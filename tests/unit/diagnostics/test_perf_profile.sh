#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# `dot doctor perf show --profile` printed only zprof's header: it sourced
# .zshrc under a non-interactive `zsh -c`, where the interactive config
# returns early, so no startup function was ever profiled. The profile now
# runs a real interactive zsh with zprof loaded before any startup file.
# A sandbox HOME supplies a .zshenv/ZDOTDIR/.zshrc whose startup calls a
# named function; the report must list it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PERF="$REPO_ROOT/scripts/diagnostics/perf.sh"
if ! command -v zsh >/dev/null 2>&1; then
  echo "SKIP: zsh not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
H="$WORK/home"
mkdir -p "$H/.config/zsh"
printf 'export ZDOTDIR="$HOME/.config/zsh"\n' >"$H/.zshenv"
cat >"$H/.config/zsh/.zshrc" <<'RC'
# Like the real config: only an interactive shell gets this far.
[[ -o interactive ]] || return 0
dotfiles_probe_startup_fn() { local i; for i in {1..200}; do :; done; }
dotfiles_probe_startup_fn
RC

test_start "profile_lists_functions_run_at_interactive_startup"
out="$(env -i HOME="$H" PATH="$PATH" TERM=dumb NO_COLOR=1 \
  XDG_CACHE_HOME="$H/.cache" XDG_STATE_HOME="$H/.state" \
  bash "$PERF" --shell zsh --runs 1 --target 100000 --no-baseline-check --profile 2>&1 </dev/null)"
assert_contains "Top contributors (zprof)" "$out" "the profile section is rendered"
assert_contains "dotfiles_probe_startup_fn" "$out" "and names the function .zshrc ran"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
