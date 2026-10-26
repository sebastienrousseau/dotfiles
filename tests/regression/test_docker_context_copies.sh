#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# test-kind: structural
# Regression: v0.2.537 added .clusterfuzzlite/ and fuzz/ to the root
# .dockerignore, so the ClusterFuzzLite image could no longer COPY its
# own build.sh. The PR fuzz workflow only runs when those paths change,
# so nothing failed until a Dependabot bump touched its workflow.
# Regression for: 26c1d5af
# Why: an ignore pattern must never drop a file a Dockerfile copies.
#
# Every Dockerfile built from the repository root is checked against the
# ignore file BuildKit uses for it: <Dockerfile>.dockerignore beside it
# when present, else the root .dockerignore. Patterns are matched the
# way this repository writes them: a path or directory prefix, or a
# `*.ext` suffix. fuzz/oss-fuzz/Dockerfile is built by OSS-Fuzz from its
# own directory and is out of scope.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ROOT_CONTEXT_DOCKERFILES=(
  .clusterfuzzlite/Dockerfile
  .devcontainer/Dockerfile
  tests/Dockerfile.sandbox
  tests/Dockerfile.test
)

# ignore_file_for <dockerfile> — the ignore file BuildKit reads.
ignore_file_for() {
  if [[ -f "$REPO_ROOT/$1.dockerignore" ]]; then
    printf '%s\n' "$REPO_ROOT/$1.dockerignore"
  else
    printf '%s\n' "$REPO_ROOT/.dockerignore"
  fi
}

# excluded_by <ignore-file> <path> — print the pattern that drops <path>.
excluded_by() {
  local pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    pattern="${pattern%/}"
    case "$2" in
      "$pattern" | "$pattern"/*) printf '%s\n' "$pattern" && return 0 ;;
    esac
    if [[ "$pattern" == \*.* && "$2" == *"${pattern#\*}" ]]; then
      printf '%s\n' "$pattern" && return 0
    fi
  done <"$1"
  return 1
}

# copy_sources <dockerfile> — the context paths each COPY or ADD reads.
copy_sources() {
  awk 'toupper($1) == "COPY" || toupper($1) == "ADD" {
    n = 0
    for (i = 2; i <= NF; i++) if ($i !~ /^--/) args[++n] = $i
    for (i = 1; i < n; i++) if (args[i] != ".") print args[i]
    for (i in args) delete args[i]
  }' "$REPO_ROOT/$1"
}

test_start "excluded_by_matches_the_repository_patterns"
_fixture="$(mktemp)"
trap 'rm -f "$_fixture"' EXIT
printf '%s\n' '# comment' 'fuzz/' '*.log' '.git' >"$_fixture"
assert_equals "fuzz" "$(excluded_by "$_fixture" fuzz/go.mod)" "a directory pattern drops what is under it"
assert_equals "*.log" "$(excluded_by "$_fixture" build/out.log)" "a suffix pattern drops matching files"
assert_equals "" "$(excluded_by "$_fixture" fuzzy/build.sh || true)" "a directory pattern is not a name prefix"

for dockerfile in "${ROOT_CONTEXT_DOCKERFILES[@]}"; do
  test_start "context_keeps_copies_of_${dockerfile//[^A-Za-z0-9]/_}"
  ignore="$(ignore_file_for "$dockerfile")"
  sources="$(copy_sources "$dockerfile")"
  assert_not_empty "$(cat "$REPO_ROOT/$dockerfile")" "$dockerfile exists"
  while IFS= read -r src; do
    [[ -n "$src" ]] || continue
    assert_file_exists "$REPO_ROOT/$src" "$dockerfile copies $src, which exists"
    dropped="$(excluded_by "$ignore" "$src" || true)"
    assert_equals "" "$dropped" "${ignore#"$REPO_ROOT"/} keeps $src for $dockerfile"
  done <<<"$sources"
done

test_summary
