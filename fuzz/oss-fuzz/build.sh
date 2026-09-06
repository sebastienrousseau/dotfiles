#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# OSS-Fuzz build script — compiles every Go fuzzer in fuzz/
# against libFuzzer with $SANITIZER applied.
#
# OSS-Fuzz invokes this with:
#   /src/dotfiles/fuzz/oss-fuzz/build.sh
# from a working directory inside the docker container.
#
# Each *_test.go file under fuzz/ that contains `func Fuzz<Name>(`
# becomes a separate fuzz target binary at $OUT/Fuzz<Name>.

set -euo pipefail

cd "$SRC/dotfiles/fuzz"

# OSS-Fuzz exports: $OUT (artefact dir), $SANITIZER, $CFLAGS,
# $LIB_FUZZING_ENGINE. These are native Go fuzzers
# (func Fuzz*(f *testing.F)), so they build with compile_native_go_fuzzer,
# which rewrites the stdlib testing import to the go-118-fuzz-build shim.

# Each fuzzer below is a tested-in-isolation harness for one piece
# of input-handling code in the project. Add new harnesses by
# (1) creating fuzz/<name>_test.go with `func Fuzz<Cap>(f *testing.F)`,
# (2) appending a `compile_native_go_fuzzer` call here.

# IMPORTANT: each harness file must be SELF-CONTAINED.
# compile_native_go_fuzzer rewrites ONE *_test.go file into a regular .go
# file and builds it WITHOUT the package's other test files, so a harness
# that uses a symbol declared in a sibling _test.go builds under `go test`
# and then fails here with "undefined: <symbol>". Duplicate the symbol into
# the harness file, or put it in a non-test .go file in the package.
# tools/ci/check-fuzz-harness-self-contained.sh enforces this in CI.

# Harness inventory (keep in sync with docs/security/FUZZING.md):
#   FuzzValidateName / FuzzInitURLResolver - ports of the shell helpers
#   FuzzUI*  - ports of the dot-ui parsers   (defaults/dot_local/share/dot-ui)
#   FuzzAI*  - ports of the dot-ai-tui parsers (defaults/dot_local/share/dot-ai-tui)
# The dot-ui / dot-ai-tui binaries are `package main` in their own modules,
# which compile_native_go_fuzzer cannot import, so their parsers are ported
# into this package and are fuzzed in-module as well (each module's
# fuzz_test.go), where they run against the real implementation.

go get github.com/AdamKorcz/go-118-fuzz-build/testing

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzValidateName \
  fuzz_validate_name

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzInitURLResolver \
  fuzz_init_url_resolver

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzUIEventLine \
  fuzz_ui_event_line

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzUIHexColor \
  fuzz_ui_hex_color

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzUIPickFilter \
  fuzz_ui_pick_filter

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzUIPickArgs \
  fuzz_ui_pick_args

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzUITableRows \
  fuzz_ui_table_rows

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzAISessionFile \
  fuzz_ai_session_file

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzAISqliteOutput \
  fuzz_ai_sqlite_output

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzAIFenceTag \
  fuzz_ai_fence_tag

compile_native_go_fuzzer \
  github.com/sebastienrousseau/dotfiles/fuzz \
  FuzzAIGatewayURL \
  fuzz_ai_gateway_url

# Seed corpora: copy any *_seed_corpus/ subdirectories alongside
# the binary. OSS-Fuzz picks them up automatically.
for corpus in *_seed_corpus; do
  if [[ -d "$corpus" ]]; then
    cp -r "$corpus" "$OUT/"
  fi
done
