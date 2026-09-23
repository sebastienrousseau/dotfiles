#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# dot-ai-proxy paths the lifecycle suite leaves dark: colour output on a
# real TTY (a python pty), and `local on` when the gateway token can be
# neither read nor created (its state directory sits under a regular file,
# which defeats mkdir even for root).
#
# State and config live in mktemp; nothing is started or listened on.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROXY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy"
WORK="$(mktemp -d -t aiproxy-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

H="$WORK/home"
mkdir -p "$H"

OUT=""
RC=0
px() {
  RC=0
  OUT="$(env -u DOT_AI_API_KEY -u NO_COLOR HOME="$H" XDG_CONFIG_HOME="$H/.config" \
    DOT_AI_PORT=59998 "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "ai_proxy_local_on_fails_when_token_cannot_be_created"
: >"$WORK/not-a-dir"
px XDG_STATE_HOME="$WORK/not-a-dir" NO_COLOR=1 "${BASH:-bash}" "$PROXY" local on
assert_equals 1 "$RC" "local on fails"
assert_contains "Could not read or create the gateway token" "$OUT" "token failure reported"
assert_false "[[ -e '$H/.config/dotfiles/ai-local.env' ]]" "no routing env written"

# Regression: local_status ended in `[[ -n $ANTHROPIC_BASE_URL ]] && info`,
# so with the variable unset (the normal case) `dot ai local status` exited 1.
test_start "ai_proxy_local_status_exits_0_without_anthropic_base_url"
px XDG_STATE_HOME="$H/.local/state" NO_COLOR=1 ANTHROPIC_BASE_URL= \
  "${BASH:-bash}" "$PROXY" local status
assert_equals 0 "$RC" "local status exits 0 when ANTHROPIC_BASE_URL is unset"
assert_contains "local routing: OFF" "$OUT" "routing state reported"

test_start "ai_proxy_uses_colour_on_a_tty"
if command -v python3 >/dev/null 2>&1; then
  px XDG_STATE_HOME="$H/.local/state" python3 -c '
import os, pty, sys
status = pty.spawn(sys.argv[1:])
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
' "${BASH:-bash}" "$PROXY" local status
  assert_equals 0 "$RC" "status on a TTY exits 0"
  assert_contains $'\033[36m' "$OUT" "info glyph is coloured"
  assert_contains "local routing: OFF" "$OUT" "routing state reported"
else
  assert_equals "skip" "skip" "python3 unavailable; pty case skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
