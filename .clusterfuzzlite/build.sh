#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# ClusterFuzzLite build script — compiles the Go fuzzers shared with the
# OSS-Fuzz integration. Add a harness by creating
# oss-fuzz-integration/fuzz/<name>_test.go with `func Fuzz<Cap>(f *testing.F)`
# and appending a `compile_go_fuzzer` call below.
set -euo pipefail

cd "$SRC/dotfiles/oss-fuzz-integration/fuzz"

compile_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/oss-fuzz-integration/fuzz \
  FuzzValidateName \
  fuzz_validate_name

compile_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/oss-fuzz-integration/fuzz \
  FuzzInitURLResolver \
  fuzz_init_url_resolver

# Seed corpora: copy any *_seed_corpus/ dirs alongside the binaries.
for corpus in *_seed_corpus; do
  [[ -d "$corpus" ]] && cp -r "$corpus" "$OUT/" || true
done
