#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/defaults/dot_config/nushell/aliases.nu"

# Load aliases.nu in nu and read each alias's expansion back. env.nu
# always creates the bash-alias cache it sources, so the sandbox HOME does
# too (empty, as on a first run).
NU_HOME="$(mktemp -d)"
trap 'rm -rf "$NU_HOME"' EXIT
mkdir -p "$NU_HOME/.cache/nushell"
: >"$NU_HOME/.cache/nushell/bash-aliases.nu"
for pair in "dm:dot mode list" "da:dot agent list" "dmc:dot mcp registry" "datt:dot attest --json"; do
  name="${pair%%:*}" want="${pair#*:}"
  test_start "nushell_alias_${name}"
  if NU_BIN="$(command -v nu)"; then
    got="$(HOME="$NU_HOME" "$NU_BIN" --no-config-file -c "source '$TARGET'; scope aliases | where name == '$name' | get expansion.0" 2>&1 || true)"
    assert_equals "$want" "$got" "$name expands to $want"
  else
    assert_true "true" "nu not installed; skipped"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
