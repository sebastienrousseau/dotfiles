#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Regression for: GH-1018
# shellcheck disable=SC1090,SC1091,SC2034
#
# Regression: defaults/run_before_macos-icloud-symlinks.sh.tmpl must leave a
# tree it refuses to act on BYTE-IDENTICAL.
#
# tests/regression/test_macos_icloud_symlinks_safety.sh already asserts that
# named canary files survive. That catches the deletion we know to look for.
# This test catches the one we do not: it hashes the WHOLE tree before and
# after, so any file that disappears, any file whose contents change, any
# directory that becomes a symlink, and any symlink that is repointed shows
# up as a diff — including in a path nobody thought to name.
#
# The distinction matters because the bug this whole hook exists to prevent
# (#1018) did not destroy a file anyone had listed. It destroyed a real
# ~/Documents wholesale, because chezmoi's symlink_ mechanism is
# `rm -rf $target; ln -s $source $target`. A test that only checks named
# canaries would have passed against a variant that deleted everything else.
#
# Every scenario runs against a fresh $HOME under mktemp. The real home
# directory is never read from or written to.
#
# bash 3.2 only (stock macOS): no mapfile, no associative arrays, and no
# unguarded expansion of a possibly-empty array.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TEMPLATE="${TEMPLATE:-$REPO_ROOT/defaults/run_before_macos-icloud-symlinks.sh.tmpl}"

CANDIDATES="Desktop Documents Downloads Movies Music Pictures Public"

# ---------------------------------------------------------------------------
# Render the template into a runnable script (strip the darwin guard), and
# park the hook's own output OUTSIDE the tree under audit — writing it inside
# would make the manifest report the hook's log as a change the hook made.
# ---------------------------------------------------------------------------
RENDERED="$(mktemp -t icloud-manifest.XXXXXX 2>/dev/null || mktemp)"
HOOK_OUT="$(mktemp -t icloud-manifest-out.XXXXXX 2>/dev/null || mktemp)"
SHIM_DIR="$(mktemp -d -t icloud-manifest-shim.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -f "$RENDERED" "$HOOK_OUT"; rm -rf "$SHIM_DIR"' EXIT

sed -e '/^{{- if eq \.chezmoi\.os "darwin" -}}$/d' \
    -e '/^{{- end -}}$/d' \
    "$TEMPLATE" > "$RENDERED"

# Same fallback order as lib/dot/verified-download.sh.
if command -v sha256sum >/dev/null 2>&1; then
  HASHER="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASHER="shasum -a 256"
else
  HASHER=""
fi

# ---------------------------------------------------------------------------
# _manifest <root> — one line per entry, sorted:
#
#   D <path>              a directory
#   L <path> -> <target>  a symlink, with what it points at
#   F <sha256> <path>     a regular file, with the hash of its contents
#
# $HOME/state is pruned: it holds the hook's log, which is meant to grow on
# every run. Everything else is fair game.
# ---------------------------------------------------------------------------
_manifest() {
  local root="$1"
  (
    cd "$root" 2>/dev/null || return 0
    find . -mindepth 1 -path ./state -prune -o \( -type d -o -type l \) -print 2>/dev/null |
      while IFS= read -r p; do
        if [[ -L "$p" ]]; then
          printf 'L %s -> %s\n' "$p" "$(readlink "$p" 2>/dev/null)"
        else
          printf 'D %s\n' "$p"
        fi
      done
    # One hasher invocation for the whole tree rather than one per file.
    # Guarded on a cheap `-print -quit` because BSD xargs, unlike GNU, runs
    # its utility even on empty input — and a hasher with no arguments reads
    # stdin, which would hang the suite rather than fail it.
    if [[ -n "$HASHER" ]] &&
       [[ -n "$(find . -mindepth 1 -path ./state -prune -o -type f -print -quit 2>/dev/null)" ]]; then
      find . -mindepth 1 -path ./state -prune -o -type f -print0 2>/dev/null |
        _hash_many 2>/dev/null |
        awk '{ h = $1; $1 = ""; sub(/^[ \t]+/, ""); sub(/^\*/, ""); print "F " h " " $0 }'
    fi
  ) | LC_ALL=C sort
}

# _hash_many — hash every NUL-delimited path arriving on stdin, one process
# for the lot. Dispatching by name keeps both invocations fully quoted.
_hash_many() {
  if [[ "$HASHER" == "sha256sum" ]]; then
    xargs -0 sha256sum
  else
    xargs -0 shasum -a 256
  fi
}

_new_home() {
  local sb
  sb="$(mktemp -d -t icloud-manifest-home.XXXXXX 2>/dev/null || mktemp -d)"
  mkdir -p "$sb/Library/Mobile Documents/com~apple~CloudDocs"
  mkdir -p "$sb/state/dotfiles"
  printf '%s\n' "$sb"
}

# _run <home> — drive the hook with a scrubbed environment so nothing about
# the developer's shell can influence the outcome.
_run() {
  env -i PATH="$PATH" HOME="$1" XDG_STATE_HOME="$1/state" \
    "${BASH:-bash}" "$RENDERED" >"$HOOK_OUT" 2>&1
}

# _assert_unchanged <label> <before> <after> — the whole point of this file.
_assert_unchanged() {
  local label="$1" before="$2" after="$3"
  if [[ "$before" == "$after" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf '  \033[0;32m✓\033[0m %s\n' "$label"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  \033[0;31m✗\033[0m %s: the tree changed —\n' "$label"
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") 2>/dev/null |
      sed 's/^/        /'
  fi
}

# ---------------------------------------------------------------------------
# SANITY
# ---------------------------------------------------------------------------
test_start "icloud_manifest_has_a_hasher"
if [[ -n "$HASHER" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s: %s\n' "$CURRENT_TEST" "$HASHER"
else
  # Without a hasher this file proves nothing, so say so rather than passing
  # a test that checked directory structure alone.
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: neither sha256sum nor shasum found\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# 1. THE #1018 SCENARIO — every candidate holds real content and every iCloud
#    source exists. This is the exact state in which the old mechanism
#    destroyed a user's data. Nothing at all may change.
# ---------------------------------------------------------------------------
test_start "icloud_manifest_unchanged_when_every_candidate_holds_data"
H="$(_new_home)"
IC="$H/Library/Mobile Documents/com~apple~CloudDocs"
for c in $CANDIDATES; do
  mkdir -p "$H/$c/nested/deeper" "$IC/$c"
  printf 'CANARY-%s-DO-NOT-DELETE\n' "$c" >"$H/$c/canary.txt"
  printf 'buried-%s\n' "$c" >"$H/$c/nested/deeper/buried.txt"
  printf 'hidden\n' >"$H/$c/.DS_Store"
done
BEFORE="$(_manifest "$H")"
_run "$H"
AFTER="$(_manifest "$H")"
_assert_unchanged "$CURRENT_TEST" "$BEFORE" "$AFTER"

test_start "icloud_manifest_refusal_is_reported_for_every_candidate"
REFUSALS="$(grep -c 'refusing (user data protection)' "$HOOK_OUT" 2>/dev/null || printf '0')"
assert_equals "7" "$(printf '%s' "$REFUSALS" | tr -d ' ')" \
  "each of the seven candidates should say why it was left alone"
rm -rf "$H"

# ---------------------------------------------------------------------------
# 2. THE RACE — a file lands in the target between the emptiness check and
#    the rmdir. `rmdir` must fail, and the hook must then take no action at
#    all rather than pressing on to the symlink.
#
#    The race is made deterministic with a `rmdir` shim on PATH that creates
#    the file itself, immediately before delegating to the real one. Timing a
#    real race would be flaky; this reproduces its effect exactly.
# ---------------------------------------------------------------------------
test_start "icloud_manifest_survives_the_rmdir_race"
H="$(_new_home)"
IC="$H/Library/Mobile Documents/com~apple~CloudDocs"
mkdir -p "$H/Documents" "$IC/Documents"
cat >"$SHIM_DIR/rmdir" <<'SHIM'
#!/bin/sh
# Stand in for a process that writes into the directory a moment before the
# rmdir lands. The real rmdir then fails with ENOTEMPTY, which is the
# behaviour under test.
printf 'RACED-CANARY-DO-NOT-DELETE\n' >"$1/raced.txt" 2>/dev/null
exec /bin/rmdir "$@"
SHIM
chmod +x "$SHIM_DIR/rmdir"
env -i PATH="$SHIM_DIR:$PATH" HOME="$H" XDG_STATE_HOME="$H/state" \
  "${BASH:-bash}" "$RENDERED" >"$HOOK_OUT" 2>&1
rm -f "$SHIM_DIR/rmdir"
assert_file_exists "$H/Documents/raced.txt" \
  "a file that appears mid-flight must survive the rmdir it caused to fail"

# One assert per test_start: tests/regression/test_test_framework_invariants.sh
# requires TESTS_RUN == TESTS_PASSED + TESTS_FAILED for every suite in this
# directory, and test_start counts once while each assert counts once.
test_start "icloud_manifest_raced_file_contents_are_intact"
assert_equals "RACED-CANARY-DO-NOT-DELETE" "$(cat "$H/Documents/raced.txt" 2>/dev/null)" \
  "surviving the deletion is not enough — the bytes must be unchanged too"

test_start "icloud_manifest_no_link_over_a_lost_race"
assert_false "[[ -L \"$H/Documents\" ]]" \
  "losing the race must not leave a symlink where the directory was"
rm -rf "$H"

# ---------------------------------------------------------------------------
# 3. THE ALREADY-MIGRATED MACHINE — every candidate is already a correct
#    symlink and the iCloud side holds real content. Upgrading such a machine
#    must be a pure no-op, on both sides of every link.
# ---------------------------------------------------------------------------
test_start "icloud_manifest_stable_when_already_migrated"
H="$(_new_home)"
IC="$H/Library/Mobile Documents/com~apple~CloudDocs"
for c in $CANDIDATES; do
  mkdir -p "$IC/$c/sub"
  printf 'ICLOUD-%s\n' "$c" >"$IC/$c/sub/data.txt"
  ln -s "$IC/$c" "$H/$c"
done
BEFORE="$(_manifest "$H")"
_run "$H"
_run "$H"
_run "$H"
AFTER="$(_manifest "$H")"
_assert_unchanged "$CURRENT_TEST" "$BEFORE" "$AFTER"

test_start "icloud_manifest_recognises_every_existing_link"
OKS="$(grep -c 'already symlinked to iCloud' "$HOOK_OUT" 2>/dev/null || printf '0')"
assert_equals "7" "$(printf '%s' "$OKS" | tr -d ' ')" \
  "an already-correct link should be recognised, not re-made"
rm -rf "$H"

# ---------------------------------------------------------------------------
# 4. BOTH SIDES POPULATED — the home folder and the iCloud folder each hold
#    different data. Neither may be merged into the other, moved, or lost.
# ---------------------------------------------------------------------------
test_start "icloud_manifest_never_merges_two_populated_sides"
H="$(_new_home)"
IC="$H/Library/Mobile Documents/com~apple~CloudDocs"
mkdir -p "$H/Documents" "$IC/Documents"
printf 'LOCAL-ONLY\n' >"$H/Documents/local.txt"
printf 'CLOUD-ONLY\n' >"$IC/Documents/cloud.txt"
BEFORE="$(_manifest "$H")"
_run "$H"
AFTER="$(_manifest "$H")"
_assert_unchanged "$CURRENT_TEST" "$BEFORE" "$AFTER"
rm -rf "$H"

# ---------------------------------------------------------------------------
# 5. CONVERGENCE — a mixed tree. The hook may act once, on the candidates
#    that are genuinely safe, and must then stop changing anything. This is
#    what makes `run_before_` (every apply) rather than `run_once_before_`
#    defensible, so it is worth asserting rather than assuming.
# ---------------------------------------------------------------------------
test_start "icloud_manifest_converges_then_stops_changing"
H="$(_new_home)"
IC="$H/Library/Mobile Documents/com~apple~CloudDocs"
for c in $CANDIDATES; do mkdir -p "$IC/$c"; done
mkdir -p "$H/Documents"
printf 'KEEP\n' >"$H/Documents/keep.txt"   # non-empty  -> must be refused
mkdir -p "$H/Desktop"                      # empty      -> may be linked
mkdir -p "$H/Music"
printf 'x\n' >"$H/Music/.DS_Store"         # hidden only-> must be refused
printf 'file\n' >"$H/Public"               # a file     -> must be refused
# Downloads, Movies and Pictures are absent -> may be linked
_run "$H"
SETTLED="$(_manifest "$H")"
_run "$H"
_run "$H"
AFTER="$(_manifest "$H")"
_assert_unchanged "$CURRENT_TEST" "$SETTLED" "$AFTER"

test_start "icloud_manifest_acted_only_where_it_was_safe"
if [[ -f "$H/Documents/keep.txt" ]] &&
   [[ ! -L "$H/Documents" ]] &&
   [[ -f "$H/Music/.DS_Store" ]] &&
   [[ ! -L "$H/Music" ]] &&
   [[ -f "$H/Public" ]] &&
   [[ ! -L "$H/Public" ]] &&
   [[ -L "$H/Desktop" ]] &&
   [[ -L "$H/Downloads" ]] &&
   [[ -L "$H/Movies" ]] &&
   [[ -L "$H/Pictures" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: refused and linked candidates are not as expected\n' \
    "$CURRENT_TEST"
fi
rm -rf "$H"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
