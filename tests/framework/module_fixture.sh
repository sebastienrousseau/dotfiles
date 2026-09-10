#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by tests/unit/dot-cli/*.sh; provides a fake dotfiles source tree.
# shellcheck disable=SC2034
#
# module_fixture.sh — build a throwaway "dotfiles source tree" that the
# scripts/dot/commands/*.sh modules will resolve as their own source dir.
#
# Why this exists
# ---------------
# Every command module locates the checkout through lib/dot/utils.sh's
# resolve_source_dir, whose first probe is `<lib dir>/../..`. Run a module
# from the checkout and that probe always answers "the checkout", so the
# not-installed / not-present / fall-back arms of `dot apply`, `dot docs`,
# `dot learn`, `dot mcp` and friends can never be reached: the real
# scripts/ops/chezmoi-apply.sh, README.md and docs/KEYS.md are always there.
#
# A fixture whose lib/ is a symlink to the real one moves that probe's answer
# to the fixture, so a test decides file by file what the module finds.
#
# Two rules make it measurable and safe:
#
#   * Modules are invoked by their RELATIVE path from inside the fixture
#     (`cd "$fixture" && bash scripts/dot/commands/core.sh …`). The coverage
#     aggregator resolves a relative trace source against the repo root, so
#     the run is attributed to the real module. An absolute fixture path
#     would only resolve while the fixture still exists.
#   * The fixture is NOT deleted on exit, for the same reason: aggregation
#     happens after the whole sweep, and the symlinked lib/ path inside it
#     must still resolve then. Each fixture lives at a fixed per-test path
#     and is removed and rebuilt at the start of the next run, so at most one
#     directory per test name is ever left behind.
#
# Nothing under the fixture is written through to the checkout: the symlinked
# trees (lib/, scripts/dot/, scripts/lib/) are read and sourced, never
# written, by the modules these fixtures drive.

[[ "${_DOT_LIB_MODULE_FIXTURE_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_MODULE_FIXTURE_LOADED=1

## dot_fixture_new <name> — create (or recreate) a fixture source tree and
## print its path. $REPO_ROOT must already be set by the caller.
dot_fixture_new() {
  local name="$1"
  local base="${TMPDIR:-/tmp}"
  local root="${base%/}/dot-cov-fixtures/$name"
  rm -rf "$root"
  # scripts/dot/commands and scripts/dot/data are REAL directories holding
  # per-file symlinks, not one symlink to the whole tree. A module that
  # builds a path by appending `..` to its own directory — cmd_learn does,
  # probing `<module dir>/../../../defaults/dot_local/bin` — has that `..`
  # resolved by the kernel, not lexically, so a symlinked scripts/dot would
  # walk out of the fixture and back into the checkout.
  mkdir -p "$root/scripts/dot/commands" "$root/scripts/dot/data" "$root/bin"
  ln -s "$REPO_ROOT/lib" "$root/lib"
  ln -s "$REPO_ROOT/scripts/lib" "$root/scripts/lib"
  local f
  for f in "$REPO_ROOT"/scripts/dot/commands/*; do
    [[ -e "$f" ]] || continue
    ln -s "$f" "$root/scripts/dot/commands/${f##*/}"
  done
  for f in "$REPO_ROOT"/scripts/dot/data/*; do
    [[ -e "$f" ]] || continue
    ln -s "$f" "$root/scripts/dot/data/${f##*/}"
  done
  printf '%s\n' "$root"
}

## dot_fixture_stub <dir> <name> [exit-code] — a stub executable that echoes
## its own name and arguments. `#!/bin/sh` because callers routinely hand the
## module a PATH with almost nothing on it.
dot_fixture_stub() {
  local dir="$1" name="$2" rc="${3:-0}"
  mkdir -p "$dir"
  {
    printf '#!/bin/sh\n'
    printf 'printf "%%s %%s\\n" "%s" "$*"\n' "$name"
    printf 'exit %s\n' "$rc"
  } >"$dir/$name"
  chmod +x "$dir/$name"
}

## dot_fixture_basebin <dir> [extra-tools...] — populate <dir> with symlinks
## to the ordinary system tools a command module needs, so a test can hand it
## a PATH that hides everything else. `bash` points at the shell running this
## suite: a PATH that resolved `bash` to /bin/bash 3.2 would lose the run's
## coverage entirely, since that shell has no BASH_XTRACEFD and its xtrace
## would go to the stderr the caller captures.
dot_fixture_basebin() {
  local dir="$1"
  shift
  local tool resolved
  mkdir -p "$dir"
  ln -sf "${BASH:-$(command -v bash)}" "$dir/bash"
  for tool in sh sed grep find sort head tail cut tr wc awk uniq mktemp \
    cp mv rm rmdir cat cmp diff basename dirname date chmod mkdir stat \
    tput uname id printf env touch ln readlink sleep "$@"; do
    resolved="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$resolved" ]] && ln -sf "$resolved" "$dir/$tool"
  done
}

## dot_fixture_run <fixture> <module-basename> [args...]
## Runs the module inside the fixture and captures stdout+stderr into
## DOT_FIXTURE_OUT, the status into DOT_FIXTURE_RC. The caller controls the
## environment through DOT_FIXTURE_PATH, DOT_FIXTURE_HOME and, for commands
## that prompt, DOT_FIXTURE_STDIN.
DOT_FIXTURE_OUT=""
DOT_FIXTURE_RC=0
dot_fixture_run() {
  local fixture="$1" module="$2"
  shift 2
  DOT_FIXTURE_RC=0
  DOT_FIXTURE_OUT="$(
    cd "$fixture" &&
      HOME="${DOT_FIXTURE_HOME:-$fixture/home}" \
        PATH="${DOT_FIXTURE_PATH:-$PATH}" \
        NO_COLOR=1 DOTFILES_SHOW_LOGO=0 \
        "${BASH:-bash}" "scripts/dot/commands/$module.sh" "$@" \
        2>&1 <<<"${DOT_FIXTURE_STDIN:-}"
  )" || DOT_FIXTURE_RC=$?
}
