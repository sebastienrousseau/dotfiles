#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# check-fuzz-harness-self-contained.sh — prove every OSS-Fuzz harness file
# compiles on its own.
#
# Why this exists
# ---------------
# OSS-Fuzz / ClusterFuzzLite build each target with
# `compile_native_go_fuzzer`, which rewrites ONE `*_test.go` file into a
# regular `.go` file and builds it WITHOUT the package's other test files.
# A harness that references a symbol declared in a sibling `_test.go`
# therefore passes `go test` locally and in CI, and then fails only inside
# the OSS-Fuzz builder with:
#
#     ./<file>_test.go_fuzz.go:NN: undefined: <symbol>
#
# That is a slow, expensive feedback loop, so this check reproduces the
# constraint cheaply: each harness file is type-checked alone in a scratch
# module. Anything it needs must be in the file itself (or in a non-test
# .go file of the package, which the builder does keep).
#
# Usage:
#   tools/ci/check-fuzz-harness-self-contained.sh [fuzz-module-dir]
#
# Exit codes:
#   0  every harness file type-checks in isolation
#   1  at least one harness file depends on a sibling test file
#   2  invalid invocation / missing toolchain

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FUZZ_DIR="${1:-$REPO_ROOT/fuzz}"

if [[ ! -d "$FUZZ_DIR" ]]; then
  echo "::error::fuzz module directory not found: $FUZZ_DIR"
  exit 2
fi

if ! command -v go >/dev/null 2>&1; then
  echo "::error::go toolchain not found"
  exit 2
fi

cd "$FUZZ_DIR"

# Non-test .go files stay in the package when a harness is converted, so
# they are copied alongside each candidate.
shared_files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && shared_files+=("$f")
done < <(find . -maxdepth 1 -name '*.go' ! -name '*_test.go' -print | sed 's|^\./||')

harnesses=()
while IFS= read -r f; do
  [[ -n "$f" ]] && harnesses+=("$f")
done < <(grep -l -E '^func Fuzz[A-Za-z0-9_]*\(f \*testing\.F\)' ./*_test.go 2>/dev/null | sed 's|^\./||' | sort)

if [[ "${#harnesses[@]}" -eq 0 ]]; then
  echo "::error::no fuzz harness files found in $FUZZ_DIR"
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail_count=0
for harness in "${harnesses[@]}"; do
  dir="$work/${harness%.go}"
  mkdir -p "$dir"
  cp go.mod go.sum "$dir/" 2>/dev/null || cp go.mod "$dir/"
  cp "$harness" "$dir/"
  for shared in "${shared_files[@]:-}"; do
    [[ -n "$shared" ]] && cp "$shared" "$dir/"
  done

  # `go vet` type-checks the package, which is what the builder needs to
  # succeed. Run it with the module cache already warm from the real build.
  if out=$(cd "$dir" && go vet ./... 2>&1); then
    echo "  ok   $harness"
  else
    echo "::error file=fuzz/$harness::harness is not self-contained — compile_native_go_fuzzer builds it without the package's other _test.go files"
    printf '      %s\n' "$out"
    fail_count=$((fail_count + 1))
  fi
done

echo "fuzz-harness self-containment: checked ${#harnesses[@]} harness file(s), $fail_count failure(s)"

if [[ "$fail_count" -gt 0 ]]; then
  echo ""
  echo "Fix: move the missing symbol into the harness file itself (duplicate it"
  echo "per file — the files are deliberately standalone), or into a non-test"
  echo "*.go file in the package, which the OSS-Fuzz builder does keep."
  exit 1
fi

exit 0
