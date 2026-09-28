#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# compress() is sourced into zsh as well as bash (the alias layers load it
# in both). Run it under each available shell with stub archivers that
# record their arguments, and check the output name it picks.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ARCHIVES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/archives/archives.aliases.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
for t in tar zip gzip; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$t" >"$WORK/bin/$t"
  chmod +x "$WORK/bin/$t"
done

# run_compress <shell> <args...>: prints the recorded archiver calls.
run_compress() {
  local sh="$1" d="$WORK/$1.$RANDOM"
  shift
  mkdir -p "$d" && : >"$d/a.txt" && : >"$d/b.txt"
  (cd "$d" && env -i HOME="$d" PATH="$WORK/bin:/usr/bin:/bin" CALLS="$d/calls" ARCHIVE_LOG_FILE=/dev/null \
    "$sh" -c 'source "$0"; compress "$@"' "$ARCHIVES" "$@" >/dev/null 2>&1)
  cat "$d/calls" 2>/dev/null
}

for sh in bash zsh; do
  if ! command -v "$sh" >/dev/null 2>&1; then
    echo "  ($sh not installed — skipped)"
    continue
  fi
  test_start "compress_${sh}_default_output_is_named_after_the_first_input"
  assert_equals "tar -cf a.txt.tar a.txt" "$(run_compress "$sh" tar a.txt)" "$sh: a.txt → a.txt.tar"

  test_start "compress_${sh}_last_argument_names_a_new_output"
  assert_equals "zip -r out.zip a.txt b.txt -6" "$(run_compress "$sh" zip a.txt b.txt out.zip)" \
    "$sh: a missing last argument is the output, not an input"

  test_start "compress_${sh}_single_file_format_uses_the_first_input"
  assert_equals "gzip -c -9 a.txt" "$(run_compress "$sh" gz -l 9 a.txt)" "$sh: gzip reads a.txt"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
