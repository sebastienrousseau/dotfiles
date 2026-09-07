#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for lib/dot/ai-commands.sh — the `dot ai` subcommand
# bodies. The library is sourced the way ai.sh sources it (utils.sh first),
# with `run_ai_with_context` supplied by the caller as ai.sh does.
#
# Every AI CLI, the gateway helper and the /vibe delegator are sandbox stubs
# that record their argv, so provider dispatch, install mapping and the cost
# and delegate paths are asserted without a single real tool or network call.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

AI_COMMANDS="$REPO_ROOT/lib/dot/ai-commands.sh"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/ai-out.txt"
ERRF="$DOTFILES_COV_TMPDIR/ai-err.txt"
export AI_CALLS="$DOTFILES_COV_TMPDIR/ai-calls.txt"

# stub <name> — a recording stub that also echoes any stdin it is given.
stub() {
  cat >"$BIN/$1" <<STUB
#!$REAL_BASH
printf '$1 %s\\n' "\$*" >>"\$AI_CALLS"
if [[ ! -t 0 ]]; then
  while IFS= read -r _l || [[ -n "\$_l" ]]; do printf '$1-stdin %s\\n' "\$_l" >>"\$AI_CALLS"; done
fi
exit 0
STUB
  chmod +x "$BIN/$1"
}

for t in claude codex copilot agy goose crush amp cursor-agent grok kimi \
  kiro-cli sgpt ollama opencode aider autohand vibe qwen zai \
  dot-ai-proxy dot-ai-serve mise; do
  stub "$t"
done

# run_ai_with_context is defined by the ai.sh dispatcher, not by the library;
# provide the same seam here so _ai_oneshot can be exercised.
ai() {
  : >"$AI_CALLS"
  (
    source "$REPO_ROOT/lib/dot/utils.sh"
    run_ai_with_context() {
      printf 'run_ai_with_context %s\n' "$*" >>"$AI_CALLS"
    }
    source "$AI_COMMANDS"
    "$@"
  ) >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  # stderr goes to a file and is replayed to ours: redirecting it away would
  # take the child's xtrace with it, losing the coverage of every line the
  # failing path executed.
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }
err_has() { assert_file_contains "$ERRF" "$1" "${2:-stderr contains $1}"; }
called() { assert_file_contains "$AI_CALLS" "$1" "invoked $1"; }

# ai_min — same, but with PATH cut down to the sandbox stubs plus the system
# directories. The host running this suite really does have some of the fleet
# installed, so the "not installed" branches need everything else hidden.
ai_min() {
  PATH="$BIN:${REAL_BASH%/*}:/usr/bin:/bin:/usr/sbin:/sbin" ai "$@"
}

test_start "library_exists_and_parses"
assert_file_exists "$AI_COMMANDS" "ai-commands.sh must exist"
assert_true "bash -n '$AI_COMMANDS'" "valid bash syntax"

# ── provider dispatch ───────────────────────────────────────────────────
test_start "claude_receives_the_prompt_on_stdin"
ai _ai_invoke_provider claude "write a test"
assert_equals 0 "$RC" "rc"
called "claude-stdin write a test"

test_start "flag_style_providers_get_the_prompt_as_an_argument"
ai _ai_invoke_provider copilot "hello"
assert_equals 0 "$RC" "rc"
called "copilot -sp hello"
ai _ai_invoke_provider goose "hello"
called "goose run -t hello"
ai _ai_invoke_provider crush "hello"
called "crush run hello"
ai _ai_invoke_provider amp "hello"
called "amp -x hello"
ai _ai_invoke_provider cursor "hello"
called "cursor-agent -p hello"
ai _ai_invoke_provider grok "hello"
called "grok --no-auto-update -p hello"
ai _ai_invoke_provider kimi "hello"
called "kimi -p hello --quiet"

test_start "stdin_style_providers_pipe_the_prompt"
ai _ai_invoke_provider agy "hello"
called "agy chat"
ai _ai_invoke_provider kiro "hello"
called "kiro-cli chat"
ai _ai_invoke_provider sgpt "hello"
called "sgpt --chat shell-gpt"
ai _ai_invoke_provider ollama "hello"
called "ollama run llama3.2"
ai _ai_invoke_provider opencode "hello"
called "opencode query"
ai _ai_invoke_provider aider "hello"
called "aider --msg -"
ai _ai_invoke_provider vibe "hello"
called "vibe chat"
ai _ai_invoke_provider qwen "hello"
called "qwen chat"
ai _ai_invoke_provider zai "hello"
called "zai chat"
ai _ai_invoke_provider autohand "hello"
called "autohand chat"
ai _ai_invoke_provider codex "hello"
called "codex-stdin hello"

test_start "an_unsupported_tool_is_rejected_with_rc2"
ai _ai_invoke_provider nosuchtool "hello"
assert_equals 2 "$RC" "rc"
out_has "Unsupported tool" "error"

test_start "a_failing_provider_propagates_its_exit_code"
cat >"$BIN/claude" <<STUB
#!$REAL_BASH
exit 9
STUB
chmod +x "$BIN/claude"
ai _ai_invoke_provider claude "hello"
assert_equals 9 "$RC" "rc"
stub claude

# ── oneshot ─────────────────────────────────────────────────────────────
test_start "oneshot_defaults_to_claude"
ai _ai_oneshot "explain this"
assert_equals 0 "$RC" "rc"
called "run_ai_with_context claude explain this"

test_start "oneshot_accepts_a_leading_tool_name"
ai _ai_oneshot codex "explain this"
assert_equals 0 "$RC" "rc"
called "run_ai_with_context codex explain this"

test_start "a_non_tool_first_word_stays_part_of_the_prompt"
ai _ai_oneshot "codexish prompt"
assert_equals 0 "$RC" "rc"
called "run_ai_with_context claude codexish prompt"

# ── cockpit / chat ──────────────────────────────────────────────────────
test_start "cockpit_runs_the_fallback_when_the_tui_is_absent"
ai _ai_cockpit printf 'fallback ran\n'
assert_equals 0 "$RC" "rc"
out_has "fallback ran" "fallback output"

test_start "chat_without_a_tool_falls_back_to_status"
ai bash -c 'cmd_ai_status() { echo "status listing"; }; source "$0"; cmd_ai_chat' "$AI_COMMANDS"
assert_equals 0 "$RC" "rc"
out_has "status listing" "status shown"

test_start "chat_with_an_uninstalled_tool_reports_it"
ai cmd_ai_chat definitely-not-installed
assert_equals 1 "$RC" "rc"
out_has "not installed" "error"

# ── serve ───────────────────────────────────────────────────────────────
test_start "serve_start_routes_the_fleet_through_the_proxy"
ai _ai_serve
assert_equals 0 "$RC" "rc"
called "dot-ai-proxy start"
called "dot-ai-proxy local on"

test_start "serve_stop_unroutes_and_stops"
ai _ai_serve stop
assert_equals 0 "$RC" "rc"
called "dot-ai-proxy local off"
called "dot-ai-proxy stop"

test_start "serve_status_logs_and_setup_are_forwarded"
ai _ai_serve status
called "dot-ai-proxy status"
ai _ai_serve logs -f
called "dot-ai-proxy logs -f"
ai _ai_serve setup
called "dot-ai-proxy setup"

test_start "serve_rejects_an_unknown_subcommand"
ai _ai_serve nonsense
assert_equals 1 "$RC" "rc"
out_has "dot ai serve [stop|status|logs|setup]" "usage"

test_start "serve_requires_the_proxy_helper"
rm -f "$BIN/dot-ai-proxy"
ai_min _ai_serve
assert_equals 1 "$RC" "rc"
out_has "not found — run: chezmoi apply" "hint"
stub dot-ai-proxy

# ── doctor ──────────────────────────────────────────────────────────────
test_start "doctor_reports_the_fleet_and_the_gateway"
ai cmd_ai_doctor
assert_equals 0 "$RC" "rc"
out_has "AI doctor" "header"
out_has "claude CLI" "engine row"
out_has "gateway engine" "gateway row"
out_has "Fleet" "fleet tally"
called "dot-ai-proxy status"

test_start "doctor_flags_a_missing_engine_and_gateway"
NONE="$DOTFILES_COV_TMPDIR/nofleet"
mkdir -p "$NONE"
ln -sf "$REAL_BASH" "$NONE/bash"
for c in printf cat sed grep tr cut awk dirname basename head tty locale uname date \
  rm mkdir realpath readlink mktemp chmod wc touch sort id; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NONE/$c"
done
PATH="$NONE" ai cmd_ai_doctor
assert_equals 0 "$RC" "rc"
out_has "not installed (the gateway engine needs it)" "engine missing"
out_has "dot-ai-serve not deployed" "gateway missing"
out_has "0/19 tools installed" "empty fleet"

# ── install ─────────────────────────────────────────────────────────────
test_start "install_reports_a_complete_fleet"
ai_min cmd_ai_install
assert_equals 0 "$RC" "rc"
out_has "all tools already installed" "nothing to do"

test_start "installing_an_already_present_tool_is_a_no_op"
ai_min cmd_ai_install codex
assert_equals 0 "$RC" "rc"
out_has "already installed" "no-op"

test_start "a_missing_tool_is_installed_through_mise"
rm -f "$BIN/opencode"
ai_min cmd_ai_install opencode
assert_equals 0 "$RC" "rc"
called "mise use -g npm:opencode-ai@latest"
out_has "installed" "success line"
stub opencode

test_start "a_tool_with_no_installer_mapping_is_skipped"
ai_min cmd_ai_install definitely-not-a-tool
assert_equals 0 "$RC" "rc"
out_has "no installer mapping — skipping" "warning"

test_start "native_installers_are_preferred_for_the_tools_that_have_one"
rm -f "$BIN/claude" "$BIN/goose"
ai_min cmd_ai_install
assert_equals 0 "$RC" "rc"
out_has "Installing" "progress line"
stub claude
stub goose

test_start "an_empty_fleet_routes_each_tool_to_its_installer"
# With nothing on PATH every tool is missing, so each native-installer arm
# and the mise mapping arm runs. The native installers fetch over the
# network, which cannot happen here (no curl on this PATH), and the
# library's contract is that a failed install is reported, never fatal.
PATH="$NONE" ai cmd_ai_install
assert_equals 0 "$RC" "rc"
out_has "Installing" "progress line"
out_has "19 missing tool(s)" "the whole fleet is missing"
out_has "mise not available" "the mise arm reports the missing installer"
out_has "run 'dot ai tools' to verify" "closing hint"

# ── delegate / cost ─────────────────────────────────────────────────────
VIBE_TOOLS="$HOME/.claude/skills/vibe/tools"
mkdir -p "$VIBE_TOOLS"
cat >"$VIBE_TOOLS/vibe-delegate" <<STUB
#!$REAL_BASH
printf 'vibe-delegate %s\\n' "\$*" >>"\$AI_CALLS"
STUB
cat >"$VIBE_TOOLS/delegate-report" <<STUB
#!$REAL_BASH
printf 'delegate-report %s\\n' "\$*" >>"\$AI_CALLS"
STUB
chmod +x "$VIBE_TOOLS/vibe-delegate" "$VIBE_TOOLS/delegate-report"

test_start "delegate_requires_a_prompt"
ai cmd_ai_delegate
assert_equals 1 "$RC" "rc"
out_has "dot ai delegate" "usage"

test_start "delegate_passes_cwd_prompt_and_bounds_to_the_delegator"
ai cmd_ai_delegate "add a changelog entry" 4 reviewer 90
assert_equals 0 "$RC" "rc"
called "vibe-delegate"
assert_file_contains "$AI_CALLS" "add a changelog entry 4 reviewer 90" "argv forwarded"

test_start "delegate_defaults_the_optional_bounds"
ai cmd_ai_delegate "just the prompt"
assert_equals 0 "$RC" "rc"
assert_file_contains "$AI_CALLS" "just the prompt 10  180" "defaults applied"

test_start "delegate_requires_the_vibe_cli"
rm -f "$BIN/vibe"
ai_min cmd_ai_delegate "prompt"
assert_equals 1 "$RC" "rc"
out_has "mise use -g pipx:mistral-vibe" "install hint"
stub vibe

test_start "delegate_reports_a_missing_delegator_tool"
mv "$VIBE_TOOLS/vibe-delegate" "$VIBE_TOOLS/vibe-delegate.bak"
ai cmd_ai_delegate "prompt"
assert_equals 1 "$RC" "rc"
err_has "not found at" "error names the path"
err_has "chezmoi apply" "hint"
mv "$VIBE_TOOLS/vibe-delegate.bak" "$VIBE_TOOLS/vibe-delegate"

test_start "cost_forwards_to_the_delegate_report"
ai cmd_ai_cost --since 7d
assert_equals 0 "$RC" "rc"
called "delegate-report --since 7d"

test_start "deprecation_notice_names_the_new_command"
ai _ai_deprecated "dot ai chat"
assert_equals 0 "$RC" "rc"
err_has "use: dot ai chat" "hint"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
