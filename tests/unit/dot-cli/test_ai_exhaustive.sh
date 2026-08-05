#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Exhaustive runtime exercise of the `dot ai` surface — drives line
# coverage across scripts/dot/commands/ai.sh and the extracted command
# bodies in lib/dot/ai-commands.sh + lib/dot/ai-install.sh. The fleet and
# installers are mocked so each verb, bridge, deprecated alias, raw-mode
# path, cold-cache probe, and install branch executes without touching the
# host or the network.
#
# Kept lean (each scenario covers a distinct path; redundant loop iterations
# are avoided) so it finishes well inside the coverage runner's per-test
# timeout even under parallel load. The `dot` framework invokes this script
# as `ai.sh ai <verb> …`, so verbs pass a leading `ai`; bridges do not.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

AI_SCRIPT="$REPO_ROOT/scripts/dot/commands/ai.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

MB="$DOTFILES_COV_TMPDIR/bin"
AI_TOOLS=(claude codex copilot goose crush amp cursor-agent grok opencode aider
  kimi autohand vibe qwen zai agy sgpt ollama kiro-cli dot-ai-serve dot-ai-proxy
  dot-ai-log dot-ai-tui)

mk_tool() {
  printf '#!/usr/bin/env bash\ncat >/dev/null 2>&1 || true\nexit 0\n' >"$MB/$1"
  chmod +x "$MB/$1"
}
for t in npm pipx cargo go uv "${AI_TOOLS[@]}"; do mk_tool "$t"; done

# gum: choose returns a tool (exercises the launch arm); confirm → yes;
# spin runs the wrapped command; style/format pass through.
cat >"$MB/gum" <<'GUM'
#!/usr/bin/env bash
case "${1:-}" in
  choose) echo "Claude Code" ;;
  confirm) exit 0 ;;
  spin) shift; while [[ $# -gt 0 && "${1:-}" != "--" ]]; do shift; done; [[ "${1:-}" == "--" ]] && shift; "$@" ;;
  style | format | join) shift; printf '%s\n' "$*" ;;
  *) : ;;
esac
exit 0
GUM
chmod +x "$MB/gum"

# Steering pattern in the sandboxed XDG config (NOT $HOME/.dotfiles, which
# cov_setup_sandbox symlinks to the real repo — writing there pollutes it).
mkdir -p "$HOME/.config/ai/patterns"
printf '# architect\n' >"$HOME/.config/ai/patterns/architect.md"

# ex <label> <args…> — run ai.sh, keep stderr (xtrace) connected, tolerate rc.
# No inner timeout: every call is a fast mocked no-op, and the coverage
# runner already wraps each test in its own timeout.
ex() {
  local label="$1"
  shift
  test_start "ai_ex_${label}"
  set +e
  bash "$AI_SCRIPT" "$@" </dev/null >/dev/null
  local rc=$?
  set -e
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
}

# ── Phase A: fleet present — one scenario per distinct path ──────────────
ex bare ai                             # _ai_cockpit → cmd_ai_status
ex tools ai tools                      # cmd_ai_status (warm cache render)
ex doctor ai doctor                    # cmd_ai_doctor
ex cost ai cost                        # cmd_ai_cost
ex serve ai serve                      # _ai_serve
ex serve_status ai serve status        # _ai_serve status
ex chat ai chat                        # cmd_ai_chat (picker)
ex chat_tool ai chat claude            # cmd_ai_chat (direct)
ex run ai run claude "hello"           # _ai_oneshot → run_ai_with_context
ex bridge_codex codex "hi"             # bridge + non-claude routing source
ex bridge_crush crush "hi"             # new agent: crush run
ex bridge_amp amp "hi"                 # new agent: amp -x
ex bridge_cursor cursor-agent "hi"     # new agent: cursor-agent -p
ex bridge_grok grok "hi"               # new agent: grok -p
ex bridge_kimi kimi "hi"               # new agent: kimi -p --quiet
ex oneshot_crush ai crush "hi"         # dot ai <newtool> → _ai_oneshot routing
ex bareprompt ai "summarise"           # _ai_oneshot bare prompt
ex style ai --style architect "tune"   # steering-pattern path
ex ask ai ask "2+2"                    # cmd_ai_query
ex delegate ai delegate "write a test" # cmd_ai_delegate
ex login ai login                      # cmd_ai_setup
ex help ai --help                      # bridge usage
ex dep_status ai status                # deprecated → cmd_ai_status
ex dep_dash ai dashboard               # deprecated → cockpit
ex dep_proxy ai proxy start            # deprecated proxy
ex unknown ai notacommand              # unknown verb → error
ex top_setup ai-setup                  # deprecated top-level
# cold cache → the probe/refresh path (_ai_refresh_status_cache, version)
rm -f "$HOME/.cache/dotfiles/ai/status.tsv"
ex tools_cold ai tools
# raw mode (clean stdout path)
export DOT_AI_RAW=1
ex raw_claude ai claude "hi"
unset DOT_AI_RAW

# ── Phase B: fleet ABSENT — install + not-installed branches ─────────────
# Restrict PATH so the host's real claude/codex aren't found (otherwise
# install short-circuits to "already installed"); keep the mocked installers.
for t in "${AI_TOOLS[@]}"; do rm -f "$MB/$t"; done
export PATH="$MB:/usr/bin:/bin"
ex install_all ai install all             # bulk install loop
ex install_claude ai install claude       # native installer dispatch
ex install_codex ai install codex         # mise-package install path
ex install_crush ai install crush         # npm-package via mise
ex install_cursor ai install cursor-agent # native installer dispatch
ex install_kimi ai install kimi           # native installer dispatch
ex install_unknown ai install nope        # unmapped tool
rm -f "$HOME/.cache/dotfiles/ai/status.tsv"
ex tools_absent ai tools      # status, nothing installed
ex absent_codex ai codex "hi" # not-installed → gum-confirm install
ex absent_agy ai agy "hi"     # agy native-installer hint branch
ex absent_kimi ai kimi "hi"   # Kimi native-installer hint branch

# Static guards keep the file meaningful without xtrace.
test_start "ai_exhaustive_files_present"
assert_file_exists "$AI_SCRIPT" "ai.sh present"
assert_file_exists "$REPO_ROOT/lib/dot/ai-commands.sh" "ai-commands.sh present"
assert_file_exists "$REPO_ROOT/lib/dot/ai-install.sh" "ai-install.sh present"

echo "RESULTS:${TESTS_RUN:-0}:${TESTS_PASSED:-0}:${TESTS_FAILED:-0}"
