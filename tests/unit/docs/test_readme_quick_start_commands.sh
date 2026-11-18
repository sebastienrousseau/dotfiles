#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Every `dot` line in the README's Quick Start is a spelling ADR-020
# declares (D11): `dot help <spelling>` resolves it to a domain, command or
# shortcut, so the first commands a reader runs are never a legacy
# fallback such as `dot theme rebuild` or `dot theme toggle`.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The `dot ...` lines of the first code block after "## Quick Start",
# without their comments.
lines="$(awk '/^## Quick Start/ { q = 1 } q && /^```/ { if (inblock) exit; inblock = 1; next }
  inblock && /^dot / { sub(/[[:space:]]*#.*/, ""); print }' "$REPO_ROOT/README.md")"

test_start "quick_start_has_dot_commands"
assert_not_empty "$lines" "the Quick Start block lists dot commands"

test_start "every_quick_start_command_is_declared"
undeclared=""
while IFS= read -r line; do
  # shellcheck disable=SC2086 # the line is words
  set -- $line
  shift
  # `dot help <words>` answers for a declared spelling (or the arguments
  # after one) and exits 127 for a verb no command declares.
  if ! HOME="$WORK" NO_COLOR=1 "$BASH_BIN" "$REPO_ROOT/bin/dot" help "$@" >/dev/null 2>&1 </dev/null; then
    undeclared="$undeclared [$line]"
  fi
done <<<"$lines"
assert_equals "" "$undeclared" "no undeclared spelling"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
