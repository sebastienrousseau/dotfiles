#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2016,SC2034,SC2317
# Unit tests for the dot AI bridge command (scripts/dot/commands/ai.sh).
#
# Every case runs ai.sh: the bridge prompt it builds (system metadata,
# --pattern/--style/-p steering), the grouped provider listing of
# `dot ai tools`, its status cache (cold probe, warm read, TTL expiry), and
# the gum launcher's labels on a pseudo-terminal. The lib/dot/ai-commands.sh
# bodies are exported recording stubs (the lib's re-source guard is set);
# gum and every provider binary are PATH stubs; HOME/XDG live in a mktemp
# sandbox; nothing touches the network or a real AI CLI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

AI_SCRIPT="$REPO_ROOT/scripts/dot/commands/ai.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ai-cmd.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state" XDG_DATA_HOME="$HOME/.local/share"
export TMPDIR="$WORK" DOTFILES_SHOW_LOGO=0 DOTFILES_AI_PROBE_JOBS=2 NO_COLOR=1
unset DOT_AI_RAW DOTFILES_NONINTERACTIVE DOTFILES_AI_STATUS_TTL DOTFILES_ACCESSIBILITY
mkdir -p "$XDG_CONFIG_HOME/ai/patterns" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
CACHE="$XDG_CACHE_HOME/dotfiles/ai/status.tsv"
CALLS="$WORK/calls"
: >"$CALLS"
export CALLS
printf 'PATTERN-MARKER: think like an architect\n' >"$XDG_CONFIG_HOME/ai/patterns/architect.md"

# ── lib stubs (exported; the lib's guard keeps ai.sh from redefining) ─────
export _DOT_LIB_AI_COMMANDS_LOADED=1 _DOT_LIB_AI_INSTALL_LOADED=1
_ai_deprecated() { :; }
_ai_invoke_provider() { printf 'invoke %s <<%s>>\n' "$1" "$2" >>"$CALLS"; }
_ai_in_scratch_dir() { "$@"; }
_ai_mise_pkg() { echo ""; }
_ai_cockpit() { "$@"; }
export -f _ai_deprecated _ai_invoke_provider _ai_in_scratch_dir _ai_mise_pkg _ai_cockpit

# ── PATH stubs ────────────────────────────────────────────────────────────
BIN="$WORK/bin"
mkdir -p "$BIN"
stub() {
  printf '#!%s\n%s\n' "$REAL_BASH" "$2" >"$1"
  chmod +x "$1"
}
# provider <bin> <version> — a CLI that reports its version and records a launch.
provider() {
  stub "$BIN/$1" "[[ \"\$*\" == --version ]] && { echo \"$1 $2\"; exit 0; }
echo \"launched $1 \$*\" >>\"\$CALLS\""
}
stub "$BIN/gum" '
case "$1" in
  choose)
    { printf "ARGS:"; printf " %s" "$@"; printf "\n"; cat; } >>"$CALLS"
    printf "%s\n" "${GUM_LAUNCH:-}" ;;
esac
exit 0'
BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$BIN:$BASE_PATH"

OUT="$WORK/out"
ai() {
  local rc=0
  "$REAL_BASH" "$AI_SCRIPT" "$@" >"$OUT" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}

# ===========================================================================
test_start "ai_bridge_runs_prompt_through_run_ai_with_context"
provider claude 2.1.0
: >"$CALLS"
rc="$(ai cl "hello there")"
assert_equals "0" "$rc" "bridge exits 0"
assert_file_contains "$CALLS" "invoke cl <<" "provider invoked for the bridge tool"
assert_file_contains "$CALLS" "## User Request" "user request section present"
assert_file_contains "$CALLS" "hello there>>" "prompt text passed through last"

test_start "ai_bridge_metadata_injection"
assert_file_contains "$CALLS" "## System Metadata" "system metadata header injected"
assert_file_contains "$CALLS" "- OS: $(uname -s) $(uname -r)" "OS line injected"
assert_file_contains "$CALLS" "- Arch: $(uname -m)" "arch line injected"
: >"$CALLS"
rc="$(DOT_AI_RAW=1 ai cl "raw one")"
assert_equals "0" "$rc" "raw bridge exits 0"
assert_file_contains "$CALLS" "invoke cl <<raw one>>" "raw mode passes the bare prompt"

test_start "ai_bridge_pattern_handling"
for flag in --pattern --style -p; do
  : >"$CALLS"
  rc="$(ai cl "$flag" architect "design it")"
  assert_equals "0" "$rc" "$flag exits 0"
  assert_file_contains "$CALLS" "<<PATTERN-MARKER: think like an architect" "$flag prepends the pattern"
  assert_file_contains "$OUT" "with pattern: architect" "$flag names the pattern"
done
rc="$(ai cl --pattern nope "x")"
assert_equals "1" "$rc" "unknown pattern exits 1"
assert_file_contains "$OUT" "Pattern not found" "unknown pattern reported"

test_start "ai_bridge_help_shows_styles"
rc="$(ai cl --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Available styles" "styles heading"
assert_file_contains "$OUT" "  - architect" "sandbox style listed"

# ── status listing ────────────────────────────────────────────────────────
for p in "copilot 1.0.11" "crush 0.9.4" "amp 0.0.17" "cursor-agent 2025.09.12" \
  "grok 0.3.1" "kimi 1.4.0"; do
  # shellcheck disable=SC2086
  provider $p
done
rm -f "$BIN/claude"

test_start "ai_status_lists_new_providers"
rm -f "$CACHE"
rc="$(ai ai tools)"
assert_equals "0" "$rc" "tools exits 0 off a TTY"
for row in "Copilot CLI|1.0.11 — GitHub Copilot in the terminal" \
  "Crush|0.9.4 — Charm's glamorous TUI coding agent" \
  "Amp|0.0.17 — Sourcegraph's agentic coder" \
  "Cursor CLI|2025.09.12 — Cursor's terminal agent" \
  "Grok Build|0.3.1 — xAI's terminal coding agent" \
  "Kimi CLI|1.4.0 — Moonshot AI's terminal coding agent"; do
  name="${row%%|*}"
  line="$(grep -F "$name " "$OUT" | head -1)"
  assert_contains "${row#*|}" "$line" "$name listed with its probed binary's version"
done
assert_contains "Claude Code" "$(grep -F "(not installed)" "$OUT")" "absent claude listed as not installed"

test_start "ai_status_has_grouped_sections"
sections="$(grep -E '^== ' "$OUT")"
assert_equals "== Agents (autonomous) ==
== Coding (interactive) ==
== General (prompt-based) ==
== Runtime (local) ==
== Cloud (platform) ==" "$sections" "five groups in order"
order="$(grep -oE '^== .* ==$|Kimi CLI|Aider|Shell-GPT|Ollama|Kiro CLI' "$OUT")"
assert_equals "== Agents (autonomous) ==
Kimi CLI
== Coding (interactive) ==
Aider
== General (prompt-based) ==
Shell-GPT
== Runtime (local) ==
Ollama
== Cloud (platform) ==
Kiro CLI" "$order" "each tool sits under its group"

test_start "ai_status_caches_presence_and_versions"
assert_file_exists "$CACHE" "cold run writes the shared status cache"
assert_file_contains "$CACHE" $'copilot\t1\t1.0.11' "installed row carries the version"
assert_file_contains "$CACHE" $'claude\t0\t' "absent row recorded"
provider copilot 9.9.9
rc="$(ai ai tools)"
assert_contains "1.0.11 —" "$(grep -F 'Copilot CLI' "$OUT")" "warm cache is read, not re-probed"
rc="$(DOTFILES_AI_STATUS_TTL=0 ai ai tools)"
assert_contains "9.9.9 —" "$(grep -F 'Copilot CLI' "$OUT")" "expired cache is refreshed"
assert_file_contains "$CACHE" $'copilot\t1\t9.9.9' "refresh rewrites the cache"
cached="$(
  set -- --help
  # shellcheck source=../../../scripts/dot/commands/ai.sh
  source "$AI_SCRIPT" >/dev/null 2>&1
  _ai_get_cached_status
)"
assert_equals "$(<"$CACHE")" "$cached" "_ai_get_cached_status prints the cache"

# ── launcher on a pseudo-terminal ─────────────────────────────────────────
TTY_OUT="$WORK/tty.out"
tty_ai() {
  local inner="$WORK/tty_inner.sh" rcfile="$WORK/tty.rc"
  rm -f "$rcfile"
  printf '%s %q ai tools\necho $? >%q\n' "$REAL_BASH" "$AI_SCRIPT" "$rcfile" >"$inner"
  {
    local _i=0
    # script(1) hangs up once its stdin hits EOF; hold it open until done.
    while [[ ! -f "$rcfile" && $_i -lt 1800 ]]; do
      sleep 0.1
      _i=$((_i + 1))
    done
  } | if [[ "$(uname -s)" == Darwin ]]; then
    script -q "$TTY_OUT.raw" "$REAL_BASH" "$inner" >/dev/null 2>&1
  else
    # util-linux script(1) runs through $SHELL; dash would drop BASH_FUNC_*.
    SHELL="$REAL_BASH" script -qec "$REAL_BASH '$inner'" "$TTY_OUT.raw" >/dev/null 2>&1
  fi
  tr -d '\r' <"$TTY_OUT.raw" >"$TTY_OUT"
  cat "$rcfile" 2>/dev/null || echo 255
}

test_start "ai_picker_is_flat_with_role_labels"
if ! command -v script >/dev/null 2>&1; then
  echo "  script(1) missing — pty case skipped"
else
  # Every row cached so the missing-provider prompt stays out of the way.
  mkdir -p "$(dirname "$CACHE")"
  : >"$CACHE"
  for b in claude codex goose crush amp cursor-agent grok kimi opencode \
    autohand vibe qwen zai sgpt agy kiro-cli; do
    printf '%s\t0\t\n' "$b" >>"$CACHE"
  done
  printf 'copilot\t1\t1.0.11\naider\t1\t0.86.1\nollama\t1\t0.12.0\n' >>"$CACHE"
  : >"$CALLS"
  # PATH without mise: the install offer needs mise, so it is skipped.
  rc="$(DOTFILES_ACCESSIBILITY=1 GUM_LAUNCH="Copilot CLI      — agent" tty_ai)"
  assert_equals "0" "$rc" "launcher flow exits 0"
  assert_file_contains "$CALLS" "ARGS: choose --header Select an AI CLI" "picker uses Select wording"
  picker="$(sed -n '/ARGS: choose --header Select an AI CLI/,$p' "$CALLS" | sed -n '2,4p')"
  assert_equals "Copilot CLI      — agent
Aider            — coding
Ollama           — local" "$picker" "flat list of 16-wide names with role labels"
  assert_file_contains "$CALLS" "launched copilot" "picked label resolves to its binary"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
