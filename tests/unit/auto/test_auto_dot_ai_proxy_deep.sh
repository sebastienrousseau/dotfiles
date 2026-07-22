#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Deep branch coverage for defaults/dot_local/bin/executable_dot-ai-proxy.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROXY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy"

test_start "dot_ai_proxy_exists"
assert_file_exists "$PROXY" "dot-ai-proxy should exist"

test_start "dot_ai_proxy_syntax"
if bash -n "$PROXY" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "dot_ai_proxy_deep_branches_execute"
proxy_tmp="${DOTFILES_COV_TMPDIR:-${TMPDIR:-/tmp}/dotfiles-proxy-test.$$}/proxy-deep"
mkdir -p "$proxy_tmp/bin" "$proxy_tmp/home" "$proxy_tmp/state" "$proxy_tmp/config"
cat >"$proxy_tmp/bin/dot-ai-serve" <<'EOF_SERVE'
#!/usr/bin/env bash
while :; do
  sleep 1
done
EOF_SERVE
cat >"$proxy_tmp/bin/claude" <<'EOF_CLAUDE'
#!/usr/bin/env bash
exit 0
EOF_CLAUDE
cat >"$proxy_tmp/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
printf '{"status":"ok","engine":"fake","claude":"ready"}\n'
EOF_CURL
cat >"$proxy_tmp/bin/tail" <<'EOF_TAIL'
#!/usr/bin/env bash
for arg in "$@"; do
  [[ -f "$arg" ]] && cat "$arg"
done
exit 0
EOF_TAIL
chmod +x "$proxy_tmp/bin/dot-ai-serve" \
  "$proxy_tmp/bin/claude" \
  "$proxy_tmp/bin/curl" \
  "$proxy_tmp/bin/tail"
printf 'proxy log\n' >"$proxy_tmp/state/serve.log"

run_proxy() {
  HOME="$proxy_tmp/home" \
    XDG_STATE_HOME="$proxy_tmp/state" \
    XDG_CONFIG_HOME="$proxy_tmp/config" \
    PATH="$proxy_tmp/bin:$PATH" \
    DOT_AI_PORT=4567 \
    DOT_AI_SERVE_BIN=dot-ai-serve \
    bash "$PROXY" "$@" >/dev/null
}

(
  set +e
  run_proxy help
  run_proxy status
  run_proxy setup
  run_proxy logs
  run_proxy logs -f
  run_proxy local status
  run_proxy local on
  ANTHROPIC_BASE_URL="http://127.0.0.1:4567" run_proxy local status
  run_proxy local off
  run_proxy local bad
  DOT_AI_HOST=0.0.0.0 run_proxy start
  DOT_AI_HOST=0.0.0.0 DOT_AI_API_KEY=test-key run_proxy start
  run_proxy start
  run_proxy status
  run_proxy stop
  run_proxy restart
  run_proxy stop
  run_proxy unknown
) || true
if [[ -f "$proxy_tmp/state/dotfiles/ai-serve/serve.pid" ]]; then
  pid="$(cat "$proxy_tmp/state/dotfiles/ai-serve/serve.pid" 2>/dev/null || true)"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
  fi
fi
assert_dir_exists "$proxy_tmp/config/dotfiles" \
  "dot-ai-proxy deep branches used sandbox config"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
