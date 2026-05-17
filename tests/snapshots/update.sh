#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# update.sh — regenerate the golden snapshots in tests/snapshots/*.snap.
#
# Run this when you intentionally change CLI output (added a new
# command, restructured the help text, etc.). Don't run it to "fix" a
# failing snapshot test without understanding why it failed.
#
# Output convention:
#   tests/snapshots/<command>.snap
# Where <command> is the slug for the captured invocation, e.g.
#   help.snap         from `dot --help`
#   version.snap      from `dot version`
#   doctor.snap       from `dot doctor`
#   perf.snap         from `dot perf`
#   health.snap       from `dot health`
#
# Closes part of #881.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
DOT_BIN="${DOT_BIN:-$REPO_ROOT/bin/dot}"
SCRUB="$SCRIPT_DIR/scrub.sh"

if [[ ! -x "$DOT_BIN" && ! -f "$DOT_BIN" ]]; then
  echo "Error: dot binary not found at $DOT_BIN" >&2
  exit 1
fi

capture() {
  local slug="$1" ; shift
  local out="$SCRIPT_DIR/${slug}.snap"
  printf 'Updating %s ...\n' "$out"
  # Run the command; tolerate non-zero exit so we still capture the
  # output (e.g., `doctor` returns 1 when something is sub-optimal).
  DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 bash "$DOT_BIN" "$@" 2>&1 | bash "$SCRUB" > "$out" || true
}

capture help    --help
capture version version
capture doctor  doctor
capture perf    perf
capture health  health

echo ""
echo "Snapshots updated. Review with:"
echo "  git diff tests/snapshots/"
