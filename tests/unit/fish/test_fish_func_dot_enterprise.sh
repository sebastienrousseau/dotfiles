#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The fish enterprise shortcuts in dot.fish, run in fish against a `dot`
# stub that echoes the arguments it was called with.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/defaults/dot_config/fish/functions/dot.fish"

for pair in "dm:mode list" "da:agent list" "dmc:mcp registry" "datt:attest --json"; do
  fn="${pair%%:*}" want="${pair#*:}"
  test_start "fish_${fn}_runs_dot_${want// /_}"
  if ! command -v fish >/dev/null 2>&1; then
    assert_true "true" "fish not installed; skipped"
    continue
  fi
  # `dot` is redefined after sourcing so the helper calls the stub.
  # shellcheck disable=SC2016
  got="$(fish --no-config -c 'source $argv[1]; function dot; echo "dot $argv"; end; '"$fn" "$TARGET" 2>&1 || true)"
  assert_equals "dot $want" "$got" "$fn calls dot $want"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
