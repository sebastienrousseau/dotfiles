#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# `dot config export` (scripts/ops/bundle.sh) leaves the age identity out
# of the offline bundle: whoever holds the archive could otherwise decrypt
# every secret in it. Each case builds a real bundle from a sandbox HOME
# and lists what the archive holds.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BUNDLE="$REPO_ROOT/scripts/ops/bundle.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-bundle-key.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if ! command -v zstd >/dev/null 2>&1 || ! tar --zstd --version >/dev/null 2>&1; then
  echo "  tar --zstd unavailable: skipped"
  echo "RESULTS:0:0:0"
  exit 0
fi

# The bundle runs with an emptied environment: PATH holds the system
# directories and wherever tar and zstd are (Homebrew's on macOS), and the
# coverage run's tracer (BASH_ENV, PS4) is kept when there is one.
TOOLS_PATH="$(dirname "$(command -v zstd)"):$(dirname "$(command -v tar)"):/usr/bin:/bin"

# bundle_of NAME: a bundle of the sandbox home NAME; OUT, RC, and LIST (the
# archive's members, one per line).
bundle_of() {
  local home="$WORK/$1"
  RC=0
  OUT="$(env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    HOME="$home" XDG_RUNTIME_DIR="$WORK" XDG_STATE_HOME="$home/.local/state" \
    PATH="$TOOLS_PATH" TERM=dumb NO_COLOR=1 bash "$BUNDLE" "$home/out" 2>&1)" || RC=$?
  LIST="$(tar --zstd -tf "$home"/out/*.tar.zst -P 2>/dev/null)"
}

# home NAME: a home with a source checkout and a chezmoi config.
home() {
  mkdir -p "$WORK/$1/.dotfiles/defaults" "$WORK/$1/.config/chezmoi"
  printf 'sourceDir = "~/.dotfiles"\n' >"$WORK/$1/.config/chezmoi/chezmoi.toml"
  printf 'encrypted\n' >"$WORK/$1/.config/chezmoi/encrypted_secrets.age"
}

test_start "the_age_key_is_left_out"
home keyed
H="$WORK/keyed"
printf 'AGE-SECRET-KEY-1PLANTED\n' >"$H/.config/chezmoi/key.txt"
mkdir -p "$H/.config/chezmoi/keys"
printf '# created: today\nAGE-SECRET-KEY-1SECOND\n' >"$H/.config/chezmoi/keys/old-identity"
bundle_of keyed
assert_equals "0" "$RC" "the bundle is built"
assert_equals "0" "$(grep -c 'key.txt$' <<<"$LIST")" "key.txt is not in it"
assert_equals "0" "$(grep -c 'old-identity$' <<<"$LIST")" "nor an identity under another name"
assert_contains "$H/.config/chezmoi/chezmoi.toml" "$LIST" "the rest of the config is"
assert_contains "$H/.config/chezmoi/encrypted_secrets.age" "$LIST" "encrypted secrets included"
assert_contains "$H/.dotfiles" "$LIST" "and the source checkout"
assert_contains "Not in the bundle" "$OUT" "the user is told the key is not in it"
assert_contains "$H/.config/chezmoi/key.txt (your age key)" "$(tr -s ' ' <<<"$OUT")" "naming the file"

test_start "the_bundle_size_is_recorded"
size="$(wc -c <"$(ls "$H"/out/*.tar.zst)" | tr -d ' ')"
assert_contains "\"metric\":\"bundle_size\",\"value\":$size," "$(cat "$H/.local/state/dotfiles/metrics.jsonl" 2>/dev/null)" \
  "the metric is the archive's size in bytes"

test_start "without_a_key_nothing_is_left_out"
home keyless
bundle_of keyless
assert_equals "0" "$RC" "the bundle is built"
assert_contains "$WORK/keyless/.config/chezmoi/chezmoi.toml" "$LIST" "the config is in it"
assert_equals "0" "$(grep -c 'Not in the bundle' <<<"$OUT")" "and no key is mentioned"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
