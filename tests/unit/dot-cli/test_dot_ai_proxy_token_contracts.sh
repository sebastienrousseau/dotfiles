#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Gateway-token contracts of defaults/dot_local/bin/executable_dot-ai-proxy
# (`local on` → _gateway_token). The mutation gate found these unprotected:
#
#   * a freshly minted token file is exactly 43 URL-safe characters plus
#     one trailing newline, so dot-ai-serve's line reader and `read -r`
#     agree on the token (the `&& echo >>` after the random draw);
#   * a token file that exists but holds no token is a failure: `local on`
#     exits 1 and writes no routing env, instead of routing the fleet with
#     an empty key (the `[[ -n "$tok" ]] || return 1` guard);
#   * when mktemp cannot create the token's temp file nothing is written
#     and `local on` fails the same way.
#
# HOME, XDG state and config all live in a mktemp dir; PATH is stub-only,
# so nothing is started and nothing reaches the real ~/.local/state.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROXY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aiproxy-token.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

BASE="$WORK/base"
NOMKTEMP="$WORK/nomktemp"
mkdir -p "$BASE" "$NOMKTEMP"
ln -sf "${BASH:-$(command -v bash)}" "$BASE/bash"
for tool in sh mkdir mktemp tr head ln rm cat kill; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$BASE/$tool"
done
printf '#!/usr/bin/env bash\necho "mktemp: refused" >&2\nexit 1\n' >"$NOMKTEMP/mktemp"
chmod +x "$NOMKTEMP/mktemp"

OUT=""
RC=0
# px <home> <path> <args…> — run the proxy against a private HOME on a PATH
# of nothing but the given directories; sets OUT / RC.
px() {
  local home="$1" path="$2"
  shift 2
  RC=0
  mkdir -p "$home"
  OUT="$(env -u DOT_AI_API_KEY HOME="$home" XDG_STATE_HOME="$home/.local/state" \
    XDG_CONFIG_HOME="$home/.config" PATH="$path" NO_COLOR=1 DOT_AI_PORT=59997 \
    "${BASH:-bash}" "$PROXY" "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "ai_proxy_new_token_is_43_chars_and_one_newline"
H="$WORK/fresh"
px "$H" "$BASE" local on
TOKEN="$H/.local/state/dotfiles/ai-serve/gateway.token"
assert_equals 0 "$RC" "local on succeeds"
assert_file_exists "$TOKEN" "token file created"
assert_equals 44 "$(wc -c <"$TOKEN" | tr -d ' ')" "token file is 43 chars + newline"
assert_equals "0a" "$(tail -c 1 "$TOKEN" | od -An -tx1 | tr -d ' \n')" "the last byte is a newline"
tok="$(head -n 1 "$TOKEN")"
assert_true "[[ '$tok' =~ ^[A-Za-z0-9_-]{43}$ ]]" "token is 43 URL-safe characters"
assert_file_contains "$H/.config/dotfiles/ai-local.env" "ANTHROPIC_AUTH_TOKEN=\"$tok\"" "routing env carries the token"

test_start "ai_proxy_empty_token_file_fails_local_on"
H="$WORK/empty"
mkdir -p "$H/.local/state/dotfiles/ai-serve"
printf '\n' >"$H/.local/state/dotfiles/ai-serve/gateway.token"
px "$H" "$BASE" local on
assert_equals 1 "$RC" "local on fails on an empty token"
assert_contains "Could not read or create the gateway token" "$OUT" "the failure is reported"
assert_false "[[ -e '$H/.config/dotfiles/ai-local.env' ]]" "no routing env is written with an empty key"
assert_false "[[ -e '$H/.config/dotfiles/ai-local.fish' ]]" "no fish routing env either"

test_start "ai_proxy_mktemp_failure_writes_no_token"
H="$WORK/nomk"
px "$H" "$NOMKTEMP:$BASE" local on
assert_equals 1 "$RC" "local on fails when the temp file cannot be made"
assert_contains "Could not read or create the gateway token" "$OUT" "the failure is reported"
assert_false "[[ -e '$H/.local/state/dotfiles/ai-serve/gateway.token' ]]" "no token file appears"
assert_false "[[ -e '$H/.config/dotfiles/ai-local.env' ]]" "no routing env is written"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
