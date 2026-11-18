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

# `setup` decides the upstream auth: an API key, the subscription opt-in,
# or a refusal. A fake claude makes the engine check pass; a fake `dot`
# answers `dot secret show ANTHROPIC_API_KEY --raw` with $FAKE_SECRET.
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexit 0\n' >"$WORK/bin/claude"
cat >"$WORK/bin/dot" <<'EOF'
#!/bin/sh
[ "$1 $2 $3 $4" = "secret show ANTHROPIC_API_KEY --raw" ] || exit 2
[ -n "${FAKE_SECRET:-}" ] || exit 1
printf '%s\n' "$FAKE_SECRET"
EOF
chmod +x "$WORK/bin/claude" "$WORK/bin/dot"
setup_px() {
  px env -u ANTHROPIC_API_KEY -u DOT_AI_GATEWAY_SUBSCRIPTION XDG_STATE_HOME="$H/.local/state" \
    NO_COLOR=1 PATH="$WORK/bin:$PATH" "$@"
}

test_start "ai_proxy_setup_refuses_without_an_upstream_key"
setup_px "${BASH:-bash}" "$PROXY" setup
assert_equals 1 "$RC" "no key and no opt-in fails"
assert_contains "upstream: no ANTHROPIC_API_KEY" "$OUT" "the missing key is named"

test_start "ai_proxy_setup_accepts_the_subscription_opt_in"
setup_px DOT_AI_GATEWAY_SUBSCRIPTION=yes "${BASH:-bash}" "$PROXY" setup
assert_equals 0 "$RC" "the opt-in is enough"
assert_contains "upstream: subscription opt-in" "$OUT" "the opt-in is warned about"

test_start "ai_proxy_setup_reads_the_key_from_the_secret_store_on_a_tty"
if command -v python3 >/dev/null 2>&1; then
  pty_setup() {
    setup_px FAKE_SECRET="$1" python3 -c '
import os, pty, sys
status = pty.spawn(sys.argv[1:])
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
' "${BASH:-bash}" "$PROXY" setup
  }
  pty_setup sk-ant-from-store
  assert_equals 0 "$RC" "a stored key is used"
  assert_contains "upstream: an Anthropic API key is set" "$OUT" "the stored key counts as set"
  assert_equals "" "$(grep -F sk-ant-from-store <<<"$OUT")" "the key itself is never printed"
  pty_setup ""
  assert_equals 1 "$RC" "a store without the key still refuses"
  assert_contains "upstream: no ANTHROPIC_API_KEY" "$OUT" "and names the missing key"
else
  assert_equals "skip" "skip" "python3 unavailable; pty case skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
