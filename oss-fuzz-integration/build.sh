#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# OSS-Fuzz build script — compiles every Go fuzzer in fuzz/
# against libFuzzer with $SANITIZER applied.
#
# OSS-Fuzz invokes this with:
#   /src/dotfiles/oss-fuzz-integration/build.sh
# from a working directory inside the docker container.
#
# Each *_test.go file under fuzz/ that contains `func Fuzz<Name>(`
# becomes a separate fuzz target binary at $OUT/Fuzz<Name>.

set -euo pipefail

cd "$SRC/dotfiles/oss-fuzz-integration/fuzz"

# OSS-Fuzz exports: $OUT (artefact dir), $SANITIZER, $CFLAGS,
# $LIB_FUZZING_ENGINE. The compile_go_fuzzer helper takes the
# package path, fuzz-function name, and output binary name.

# Each fuzzer below is a tested-in-isolation harness for one piece
# of input-handling code in the project. Add new harnesses by
# (1) creating fuzz/<name>_test.go with `func Fuzz<Cap>(...)`,
# (2) appending a `compile_go_fuzzer` call here.

compile_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/oss-fuzz-integration/fuzz \
  FuzzValidateName \
  fuzz_validate_name

compile_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/oss-fuzz-integration/fuzz \
  FuzzInitURLResolver \
  fuzz_init_url_resolver

# Seed corpora: copy any *_seed_corpus/ subdirectories alongside
# the binary. OSS-Fuzz picks them up automatically.
for corpus in *_seed_corpus; do
  [[ -d "$corpus" ]] && cp -r "$corpus" "$OUT/" || true
done
