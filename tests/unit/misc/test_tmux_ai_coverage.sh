#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural coverage for the AI-aware tmux helper (tmux-ai): provider
# labels, descendant-process detection, fallbacks, launcher and CLI dispatch.
# All external tools (tmux, pgrep, ps) are stubs in a mktemp sandbox.
# shellcheck disable=SC1090,SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMUX_AI="$REPO_ROOT/defaults/dot_local/bin/executable_tmux-ai"
BASH_BIN="$(command -v bash)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/home/.config" \
  XDG_CACHE_HOME="$SANDBOX/home/.cache" XDG_DATA_HOME="$SANDBOX/home/.local/share"
mkdir -p "$HOME" "$SANDBOX/bin" "$SANDBOX/nopgrep" "$SANDBOX/empty" "$SANDBOX/work"

# tmux stub: records its argv, never talks to a server.
cat >"$SANDBOX/bin/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TMUX_AI_TEST_LOG"
EOF
# pgrep stub: a process tree 10 -> 20 -> 30 (30 runs the AI CLI); 40 -> 50
# with no AI anywhere.
cat >"$SANDBOX/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "-P" ]] || exit 2
case "${2:-}" in
  10) printf '20\n' ;;
  20) printf '30\n' ;;
  40) printf '50\n' ;;
  *) exit 1 ;;
esac
EOF
cat >"$SANDBOX/bin/ps" <<'EOF'
#!/usr/bin/env bash
case "${2:-}" in
  20) printf 'node node /usr/bin/npx something\n' ;;
  30) printf 'node node /opt/bin/claude --resume\n' ;;
  *) printf 'zsh -zsh\n' ;;
esac
EOF
chmod +x "$SANDBOX/bin/tmux" "$SANDBOX/bin/pgrep" "$SANDBOX/bin/ps"
# A PATH with the text tools status_label needs but no pgrep.
for tool in tr cut; do
  ln -s "$(command -v "$tool")" "$SANDBOX/nopgrep/$tool"
done
export PATH="$SANDBOX/bin:$PATH"
export TMUX_AI_TEST_LOG="$SANDBOX/tmux.log"

run_ai() { "$BASH_BIN" "$TMUX_AI" "$@"; }

test_start "tmux_ai_provider_labels"
while read -r cmd expected; do
  assert_equals "$expected" "$(run_ai status "$cmd" x)" "status $cmd -> $expected"
done <<'EOF'
Claude AI:CLAUDE
codex AI:CODEX
gh-copilot AI:COPILOT
goose AI:GOOSE
crush AI:CRUSH
cursor-agent AI:CURSOR
opencode AI:OPENCODE
autohand AI:AUTOHAND
aider AI:AIDER
gemini AI:GEMINI
kimi AI:KIMI
kiro-cli AI:KIRO
ollama AI:OLLAMA
sgpt AI:SHELL-GPT
qwen AI:QWEN
agy AI:ANTIGRAVITY
vibe AI:VIBE
grok AI:GROK
zai AI:ZAI
amp AI:AMP
EOF

test_start "tmux_ai_descendant_provider"
assert_equals "AI:CLAUDE" "$(run_ai status node 10)" \
  "an AI CLI two levels below the pane shell is detected"
assert_equals "SHELL" "$(run_ai status zsh 40)" \
  "a process tree without an AI CLI falls back to the command label"
assert_equals "CLI:NODE" "$(run_ai status node notapid)" \
  "a non-numeric pane pid skips descendant detection"
assert_equals "CLI:HTOP" "$(PATH="$SANDBOX/nopgrep" run_ai status htop 10)" \
  "missing pgrep skips descendant detection"

test_start "tmux_ai_fallback_labels"
assert_equals "SHELL" "$(run_ai status /bin/bash 99)" "shells collapse to SHELL"
assert_equals "EDITOR:NVIM" "$(run_ai status nvim 99)" "editors are labelled"
assert_equals "EDITOR:VIM" "$(run_ai status /usr/bin/vim 99)" "path is stripped"
assert_equals "SSH" "$(run_ai status ssh 99)" "ssh is labelled"
assert_equals "SHELL" "$(run_ai status '/usr/bin/!!!' 99)" \
  "a name with no printable characters becomes SHELL"
assert_equals "CLI:VERYLONGCOMMAN" "$(run_ai status verylongcommandname 99)" \
  "other commands are upper-cased and truncated to 14 characters"
assert_equals "CLI:SHELL" "$(run_ai status)" \
  "status with no command uses the literal default name"

test_start "tmux_ai_default_command_is_status"
out="$(run_ai 2>&1)"
rc=$?
assert_equals "0" "$rc" "no arguments runs the default status command"
assert_equals "CLI:SHELL" "$out" "default status prints the default label"

test_start "tmux_ai_launch_provider"
: >"$TMUX_AI_TEST_LOG"
run_ai launch claude "$SANDBOX/work"
assert_equals "0" "$?" "launch claude succeeds"
assert_equals "new-window -n ai-claude -c $SANDBOX/work exec dot ai chat claude" \
  "$(tail -1 "$TMUX_AI_TEST_LOG")" "launch opens a titled window in the cwd"
run_ai launch cockpit "$SANDBOX/work"
assert_equals "new-window -n ai-cockpit -c $SANDBOX/work exec dot ai" \
  "$(tail -1 "$TMUX_AI_TEST_LOG")" "cockpit launches dot ai"
(cd "$SANDBOX/work" && run_ai launch qwen "$SANDBOX/does-not-exist")
assert_contains "-c $SANDBOX/work exec dot ai chat qwen" \
  "$(tail -1 "$TMUX_AI_TEST_LOG")" "a missing cwd falls back to \$PWD"

test_start "tmux_ai_launch_errors"
err="$(run_ai launch nope 2>&1)"
rc=$?
assert_equals "2" "$rc" "unsupported provider exits 2"
assert_contains "unsupported provider: nope" "$err" "unsupported provider is named"
PATH="$SANDBOX/empty" run_ai launch codex "$SANDBOX/work"
assert_equals "127" "$?" "launch without tmux exits 127"

test_start "tmux_ai_cli_dispatch"
help="$(run_ai --help)"
assert_contains "Usage: tmux-ai status" "$help" "--help prints usage"
assert_contains "tmux-ai launch" "$(run_ai -h)" "-h prints usage"
err="$(run_ai bogus 2>&1)"
rc=$?
assert_equals "2" "$rc" "unknown command exits 2"
assert_contains "unknown command: bogus" "$err" "unknown command is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
