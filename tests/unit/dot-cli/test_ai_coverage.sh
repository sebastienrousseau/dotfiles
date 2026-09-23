#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034,SC2317
# Behavioural coverage for scripts/dot/commands/ai.sh: the status cache
# (cold probe and warm read), the interactive install/launch flow of
# `dot ai tools` on a pseudo-terminal (gum "Install all", "Choose which",
# the no-gum mise path, the launcher), run_ai_with_context (styles, raw
# mode, every not-installed arm, the run log), and the whole dispatcher.
#
# The lib/dot/ai-commands.sh bodies (installers, cockpit, gateway, …) are
# replaced by exported recording stubs: the lib's re-source guard is set,
# so ai.sh uses these instead. gum, mise and every provider binary are
# PATH stubs; HOME/XDG live in a mktemp sandbox; nothing touches the network.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

AI="$REPO_ROOT/scripts/dot/commands/ai.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ai-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state" XDG_DATA_HOME="$HOME/.local/share"
export TMPDIR="$WORK" DOTFILES_SHOW_LOGO=0 DOTFILES_AI_PROBE_JOBS=2
unset DOT_AI_RAW DOTFILES_NONINTERACTIVE NO_COLOR
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
CACHE="$XDG_CACHE_HOME/dotfiles/ai/status.tsv"
CALLS="$WORK/calls"
: >"$CALLS"
export CALLS

# ── lib stubs (exported; the lib's guard keeps ai.sh from redefining) ─────
export _DOT_LIB_AI_COMMANDS_LOADED=1 _DOT_LIB_AI_INSTALL_LOADED=1
_ai_deprecated() { echo "deprecated: $1" >&2; }
_ai_invoke_provider() {
  printf 'invoke %s <<%s>>\n' "$1" "$2" >>"$CALLS"
  return "${INVOKE_RC:-0}"
}
_ai_in_scratch_dir() { "$@"; }
_ai_mise_pkg() {
  case "$1" in
    claude | goose | amp | cursor-agent | grok | agy | kimi | ollama) echo "" ;;
    *) echo "npm:$1" ;;
  esac
}
_ai_stub() { echo "stub $*"; }
_ai_cockpit() { _ai_stub cockpit "$@"; }
_ai_oneshot() { _ai_stub oneshot "$@"; }
_ai_serve() { _ai_stub serve "$@"; }
cmd_ai_chat() { _ai_stub chat "$@"; }
cmd_ai_doctor() { _ai_stub doctor "$@"; }
cmd_ai_setup() { _ai_stub setup "$@"; }
cmd_ai_query() { _ai_stub query "$@"; }
cmd_ai_install() { _ai_stub install "$@"; }
cmd_ai_delegate() { _ai_stub delegate "$@"; }
cmd_ai_cost() { _ai_stub cost "$@"; }
export -f _ai_deprecated _ai_invoke_provider _ai_in_scratch_dir _ai_mise_pkg \
  _ai_stub _ai_cockpit _ai_oneshot _ai_serve cmd_ai_chat cmd_ai_doctor \
  cmd_ai_setup cmd_ai_query cmd_ai_install cmd_ai_delegate cmd_ai_cost
for n in claude goose agy amp cursor grok kimi; do
  eval "install_${n}_native() { echo \"native ${n} \$1\" >>\"\$CALLS\"; }"
  export -f "install_${n}_native"
done

# ── PATH stubs ────────────────────────────────────────────────────────────
BIN="$WORK/bin"
NOGUM="$WORK/bin-nogum"
mkdir -p "$BIN" "$NOGUM"
stub() {
  printf '#!%s\n%s\n' "$REAL_BASH" "$2" >"$1"
  chmod +x "$1"
}
stub "$BIN/gum" '
case "$1" in
  style) shift; printf "%s\n" "${@: -1}" ;;
  choose)
    cat >/dev/null
    if [[ "$*" == *"Missing AI providers"* ]]; then
      printf "%s\n" "${GUM_MISSING:-Skip}"
      [[ -n "${GUM_VANISH:-}" ]] && rm -f "$0"
    elif [[ "$*" == *--no-limit* ]]; then
      printf "%b" "${GUM_PICK:-}"
    else
      printf "%s\n" "${GUM_LAUNCH:-}"
    fi ;;
  spin) [[ "$*" == *Qwen* ]] && exit 1; exit 0 ;;
  confirm) exit "${GUM_CONFIRM_RC:-0}" ;;
esac
exit 0'
stub "$BIN/mise" 'echo "mise $*" >>"$CALLS"; exit "${MISE_RC:-0}"'
stub "$BIN/claude" 'echo "launched claude $*" >>"$CALLS"; echo "2.1.0 (Claude Code)"'
stub "$BIN/codex" '[[ "$*" == --version ]] || echo "launched codex $*" >>"$CALLS"; echo "codex-cli 0.9.1"'
stub "$BIN/dot-ai-proxy" 'echo "proxy $*"'
for f in mise claude codex; do cp "$BIN/$f" "$NOGUM/$f"; done
# System dirs only: a developer machine's real provider CLIs must not leak in.
BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$BIN:$BASE_PATH"
NOGUM_PATH="$NOGUM:$BASE_PATH"
NOMISE_PATH="$WORK/empty:$BASE_PATH"
mkdir -p "$WORK/empty"

OUT="$WORK/out"
ai() {
  local rc=0
  "$REAL_BASH" "$AI" "$@" >"$OUT" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}
seed_cache() {
  mkdir -p "$(dirname "$CACHE")"
  printf 'claude\t0\t\ncodex\t1\t\ngoose\t0\t\n' >"$CACHE"
}

# ── pty runner (script(1)); xtrace records replayed on stderr ─────────────
TTY_OUT="$WORK/tty.out"
tty_ai() {
  local inner="$WORK/tty_inner.sh" rcfile="$WORK/tty.rc" rc
  rm -f "$rcfile"
  printf '%s %q ai tools\necho $? >%q\n' "$REAL_BASH" "$AI" "$rcfile" >"$inner"
  {
    local _i=0
    # script(1) hangs up the child once its stdin hits EOF, so stdin stays
    # open until the flow reports back (generous cap for a loaded CI box).
    while [[ ! -f "$rcfile" && $_i -lt 1800 ]]; do
      sleep 0.1
      _i=$((_i + 1))
    done
  } | if [[ "$(uname -s)" == Darwin ]]; then
    script -q "$TTY_OUT.raw" "$REAL_BASH" "$inner" >/dev/null 2>&1
  else
    # util-linux script(1) runs the command through $SHELL; a dash /bin/sh
    # would drop the exported BASH_FUNC_* stubs on the way through.
    SHELL="$REAL_BASH" script -qec "$REAL_BASH '$inner'" "$TTY_OUT.raw" >/dev/null 2>&1
  fi
  tr -d '\r' <"$TTY_OUT.raw" >"$TTY_OUT.all"
  grep -E '^\++@COV@:' "$TTY_OUT.all" >&2
  grep -vE '^\++@COV@:' "$TTY_OUT.all" >"$TTY_OUT"
  rc="$(cat "$rcfile" 2>/dev/null || echo 255)"
  return "$rc"
}

# ===========================================================================
test_start "status_cold_cache_probe_and_warm_read"
rm -f "$CACHE"
rc="$(PATH="$NOGUM_PATH" ai ai tools)"
assert_equals "0" "$rc" "status exits 0 off a TTY"
assert_file_exists "$CACHE" "probe writes the cache"
assert_file_contains "$CACHE" $'claude\t1\t2.1.0' "installed tool recorded with version"
assert_file_contains "$OUT" "2.1.0 — Anthropic" "claude version trimmed to first word"
rc="$(PATH="$NOGUM_PATH" ai ai status)"
assert_file_contains "$OUT" "deprecated: dot ai tools" "status is a deprecated alias"
assert_file_contains "$OUT" "not installed" "missing tools listed from warm cache"

test_start "status_nothing_installed"
mkdir -p "$(dirname "$CACHE")"
printf 'claude\t0\t\n' >"$CACHE"
rc="$(ai ai tools)"
assert_file_contains "$OUT" "No AI CLIs installed" "empty fleet warning"

# Regression: a fresh cache without a row for some tool (the fleet list grew
# since it was written, or a probe left no result) made `read` hit EOF and
# `set -e` killed `dot ai tools` silently, rc 1, mid-listing.
test_start "status_partial_cache_lists_every_tool"
printf 'claude\t1\t2.1.0\n' >"$CACHE"
rc="$(ai ai tools)"
assert_equals "0" "$rc" "a partial cache does not abort the listing"
assert_file_contains "$OUT" "Kiro CLI" "the last tool is still listed"
assert_file_contains "$OUT" "Codex CLI                           — OpenAI" "a tool with no row reads as not installed"

test_start "dead_helpers_extract_version_and_cached_status"
seed_cache
out="$(
  set -- --help
  # shellcheck source=../../../scripts/dot/commands/ai.sh
  source "$AI" >/dev/null 2>&1
  set +e
  _ai_extract_version codex
  _ai_extract_version true
  _ai_get_cached_status | head -1
)"
assert_equals $'0.9.1\ninstalled\nclaude\t0\t' "$out" "helpers behave"

if ! command -v script >/dev/null 2>&1; then
  test_start "pty_available"
  echo "  script(1) missing — pty cases skipped"
else
  test_start "tty_install_all_then_launch"
  seed_cache
  : >"$CALLS"
  GUM_MISSING="Install all" GUM_LAUNCH="Codex CLI        — agent" tty_ai
  rc=$?
  assert_equals "0" "$rc" "flow exits 0"
  assert_file_contains "$CALLS" "native goose Goose" "goose uses native installer"
  for n in claude agy amp cursor grok kimi; do
    assert_file_contains "$CALLS" "native $n " "$n uses native installer"
  done
  assert_file_contains "$TTY_OUT" "install failed (continuing)" "gum spin failure reported"
  assert_file_contains "$TTY_OUT" "Run 'dot ai' again" "done message"
  assert_file_not_exists "$CACHE" "cache invalidated after installs"
  assert_file_contains "$CALLS" "launched codex" "picked CLI is exec'd"

  test_start "tty_choose_which_to_install"
  seed_cache
  : >"$CALLS"
  GUM_MISSING="Choose which to install" GUM_PICK='Aider\n\nKimi CLI\n' GUM_LAUNCH="" tty_ai
  assert_file_contains "$CALLS" "native kimi Kimi CLI" "picked native tool installed"
  assert_file_contains "$TTY_OUT" "Aider" "picked mise tool installed"
  assert_output_not_contains "launched codex" "cat '$CALLS'"

  test_start "tty_install_without_gum_uses_mise"
  seed_cache
  : >"$CALLS"
  cp "$BIN/gum" "$WORK/gum.bak"
  # Accessibility mode keeps ui_* off gum, so the parent shell never hashes
  # its path and the self-deleting stub really is gone for the install loop.
  DOTFILES_ACCESSIBILITY=1 GUM_MISSING="Install all" GUM_VANISH=1 MISE_RC=1 tty_ai
  cp "$WORK/gum.bak" "$BIN/gum"
  assert_file_contains "$TTY_OUT" "via mise (npm:crush)" "plain mise install announced"
  assert_file_contains "$CALLS" "mise use -g npm:crush@latest" "mise invoked directly"
  assert_file_contains "$TTY_OUT" "Install gum for interactive launcher" "no-gum launcher tip"

  test_start "tty_no_gum_tips"
  seed_cache
  PATH="$NOGUM_PATH" tty_ai
  assert_file_contains "$TTY_OUT" "Install missing providers: mise install" "mise tip without gum"
fi

# ===========================================================================
test_start "bridge_usage_and_style_errors"
rc="$(ai cl --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "deprecated: dot ai cl" "top-level tool form is deprecated"
assert_file_contains "$OUT" "  - architect" "styles listed"
rc="$(ai cl)"
assert_equals "1" "$rc" "missing prompt exits 1"
rc="$(ai cl --style nope "hi")"
assert_equals "1" "$rc" "unknown style exits 1"
assert_file_contains "$OUT" "Pattern not found" "style error"

test_start "bridge_runs_with_metadata_and_logs"
mkdir -p "$HOME/.local/bin"
stub "$HOME/.local/bin/dot-ai-log" 'echo "log $*" >>"$CALLS"'
: >"$CALLS"
rc="$(ai cl --style architect "design it")"
assert_equals "0" "$rc" "bridge exits 0"
assert_file_contains "$CALLS" "## System Metadata" "metadata added"
assert_file_contains "$CALLS" "invoke cl " "provider invoked"
assert_file_contains "$CALLS" "log claude" "run logged"
mkdir -p "$XDG_CONFIG_HOME/dotfiles"
printf 'export AI_LOCAL_MARK=1\n' >"$XDG_CONFIG_HOME/dotfiles/ai-local.env"
: >"$CALLS"
rc="$(DOT_AI_RAW=1 INVOKE_RC=3 ai codex -p architect "raw prompt")"
assert_equals "3" "$rc" "provider exit code propagated"
assert_output_not_contains "System Metadata" "cat '$CALLS'"
assert_file_contains "$CALLS" "raw prompt" "raw prompt passed"
rm -f "$HOME/.local/bin/dot-ai-log"

test_start "bridge_not_installed_arms"
rc="$(GUM_CONFIRM_RC=0 ai copilot "x")"
assert_equals "0" "$rc" "gum-confirmed install proceeds"
assert_file_contains "$OUT" "Installing" "install announced"
rc="$(GUM_CONFIRM_RC=0 MISE_RC=1 ai copilot "x")"
assert_equals "1" "$rc" "mise failure exits 1"
assert_file_contains "$OUT" "installation failed" "mise failure reported"
rc="$(GUM_CONFIRM_RC=1 ai copilot "x")"
assert_equals "1" "$rc" "declined install exits 1"
assert_file_contains "$OUT" "install with: mise use -g npm:copilot@latest" "hint"
rc=0
printf 'y\n' | PATH="$NOGUM_PATH" "$REAL_BASH" "$AI" sgpt "x" >"$OUT" 2>&1 || rc=$?
assert_equals "0" "$rc" "typed yes installs"
assert_file_contains "$OUT" "[y/N]" "plain prompt shown"
rc="$(PATH="$NOGUM_PATH" ai kiro "x")"
assert_equals "1" "$rc" "EOF means no"
assert_file_contains "$OUT" "npm:kiro-cli" "kiro maps to kiro-cli"
rc="$(ai agy "x")"
assert_equals "1" "$rc" "agy not installed"
assert_file_contains "$OUT" "dot ai install agy" "agy hint"
rc="$(ai kimi "x")"
assert_equals "1" "$rc" "kimi not installed"
assert_file_contains "$OUT" "restart your shell" "kimi PATH hint"
rc="$(PATH="$NOMISE_PATH" ai zai "x")"
assert_equals "1" "$rc" "no mise"
assert_file_contains "$OUT" "mise not available" "no-mise error"

test_start "dispatcher"
rc="$(ai --help)"
assert_equals "0" "$rc" "help"
rc="$(ai)"
assert_equals "1" "$rc" "no command"
rc="$(ai frob)"
assert_equals "1" "$rc" "unknown command"
assert_file_contains "$OUT" "Unknown ai command: frob" "unknown named"
for pair in ":cockpit" "chat:chat" "tools install x:install x" "install y:install y" \
  "serve:serve" "cost:cost" "login:setup" "doctor:doctor" "ask q:query q" \
  "run p:oneshot p" "delegate d:delegate d" "dashboard:cockpit" "dash:cockpit" \
  "fix it:oneshot fix it"; do
  args="${pair%%:*}"
  want="${pair#*:}"
  # shellcheck disable=SC2086
  rc="$(ai ai $args)"
  assert_file_contains "$OUT" "stub $want" "dot ai $args"
done
rc="$(ai ai-setup a)"
assert_file_contains "$OUT" "stub setup a" "ai-setup"
rc="$(ai ai-query b)"
assert_file_contains "$OUT" "stub query b" "ai-query"
rc="$(ai ai proxy --port 1)"
assert_file_contains "$OUT" "proxy --port 1" "proxy exec'd"
rc="$(ai ai local)"
assert_file_contains "$OUT" "proxy local" "local exec'd"
rm -f "$BIN/dot-ai-proxy"
rc="$(ai ai proxy)"
assert_equals "1" "$rc" "proxy missing exits 1"
rc="$(ai ai local)"
assert_equals "1" "$rc" "local missing exits 1"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
