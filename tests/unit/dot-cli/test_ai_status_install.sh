#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for the install / launcher / bridge branches of
# scripts/dot/commands/ai.sh that test_ai_exhaustive.sh does not reach:
# the "missing providers" flow behind `dot ai tools` (gum "Install all",
# "Choose which to install", pick-nothing, no-gum tips), the launcher
# tip without gum, the run log hook, the bridge's --help / bad --style /
# kiro alias, the interactive-install prompts (gum confirm, plain read,
# mise failure, no mise) and the deprecated verbs (local, ai-query,
# tools install). Everything runs against sandboxed shims — no AI CLI,
# mise, gum or network call ever leaves the sandbox.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep bash xtrace flowing to the coverage runner's trace stream even
# when a probe below captures `2>&1`.
exec 21>&2
export BASH_XTRACEFD=21

AI_SCRIPT="$REPO_ROOT/scripts/dot/commands/ai.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

MB="$DOTFILES_COV_TMPDIR/bin"
REAL_BASH="$(command -v bash)"
REAL_JQ="$(command -v jq || true)"
ln -sf "$REAL_BASH" "$MB/bash"
[[ -n "$REAL_JQ" ]] && ln -sf "$REAL_JQ" "$MB/jq"

# Separate shim dirs so each scenario composes exactly the PATH it needs.
TOOLS="$DOTFILES_COV_TMPDIR/tools" # AI CLIs
MISE="$DOTFILES_COV_TMPDIR/mise"   # mise
GUM="$DOTFILES_COV_TMPDIR/gum"     # gum
mkdir -p "$TOOLS" "$MISE" "$GUM"
CALLS="$DOTFILES_COV_TMPDIR/calls.log"

# The sandbox bin dir ships its own `mise` shim, so "mise unavailable"
# needs a PATH that mirrors it minus that one entry.
NOMISE="$DOTFILES_COV_TMPDIR/nomise"
mkdir -p "$NOMISE"
for _b in "$MB"/*; do
  [[ "$(basename "$_b")" == "mise" ]] && continue
  ln -sf "$_b" "$NOMISE/$(basename "$_b")"
done

mk_tool() {
  printf '#!/usr/bin/env bash\ncat >/dev/null 2>&1 || true\necho "%s-ran"\nexit 0\n' "$1" >"$TOOLS/$1"
  chmod +x "$TOOLS/$1"
}

# mise: records every call; fails for the package named in MISE_FAIL_PKG.
cat >"$MISE/mise" <<'SHIM'
#!/usr/bin/env bash
printf 'mise %s\n' "$*" >>"${AI_TEST_CALLS:?}"
if [[ -n "${MISE_FAIL_PKG:-}" && "$*" == *"$MISE_FAIL_PKG"* ]]; then
  echo "mise: install failed" >&2
  exit 1
fi
exit 0
SHIM
chmod +x "$MISE/mise"

# gum: answers by --header so each prompt can be steered from the test.
#   GUM_MISSING   → answer to "Missing AI providers — install via mise?"
#   GUM_PICK      → newline-separated answer to "Select providers to install"
#   GUM_LAUNCH    → answer to "Select an AI CLI"
#   GUM_CONFIRM   → exit code for `gum confirm`
cat >"$GUM/gum" <<'SHIM'
#!/usr/bin/env bash
cmd="${1:-}"
shift || true
header=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --header) header="$2"; shift 2 ;;
    --) shift; break ;;
    *) shift ;;
  esac
done
case "$cmd" in
  choose)
    cat >/dev/null
    case "$header" in
      *"Missing AI providers"*) [[ -n "${GUM_MISSING:-}" ]] && printf '%s\n' "$GUM_MISSING" ;;
      *"Select providers"*) [[ -n "${GUM_PICK:-}" ]] && printf '%b\n' "$GUM_PICK" || exit 1 ;;
      *"Select an AI CLI"*) [[ -n "${GUM_LAUNCH:-}" ]] && printf '%s\n' "$GUM_LAUNCH" ;;
    esac
    ;;
  confirm) exit "${GUM_CONFIRM:-0}" ;;
  spin) "$@"; exit $? ;;
  style | format | join) printf '%s\n' "$*" ;;
  *) : ;;
esac
exit 0
SHIM
chmod +x "$GUM/gum"

# Run-log hook picked up by _ai_log_run.
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/dot-ai-log" <<'SHIM'
#!/usr/bin/env bash
printf 'ai-log %s\n' "$*" >>"${AI_TEST_CALLS:?}"
SHIM
chmod +x "$HOME/.local/bin/dot-ai-log"

export AI_TEST_CALLS="$CALLS"
BASE_PATH="$MB:/usr/bin:/bin"
CACHE="$HOME/.cache/dotfiles/ai/status.tsv"

# run_ai <PATH> <args…> — sets OUT / RC; status cache is cleared first so
# every scenario probes the tools visible on its own PATH.
run_ai() {
  local p="$1"
  shift
  rm -f "$CACHE"
  : >"$CALLS"
  set +e
  OUT="$(PATH="$p" bash "$AI_SCRIPT" "$@" 2>&1 </dev/null)"
  RC=$?
  set -e
}

# ── `dot ai tools`: missing providers, gum "Install all" ────────────
test_start "ai_tools_install_all_via_gum"
MISE_FAIL_PKG="pipx:aider-chat" GUM_MISSING="Install all" \
  run_ai "$GUM:$MISE:$BASE_PATH" ai tools
assert_equals 0 "$RC" "install-all flow exits 0"
assert_contains "Run 'dot ai' again to see updated status" "$OUT" "install-all completes"
assert_contains "Codex CLI" "$OUT" "codex listed"
assert_file_contains "$CALLS" "mise use -g npm:@openai/codex@latest" "codex installed through mise"
assert_file_contains "$CALLS" "mise use -g pipx:aider-chat@latest" "aider attempted through mise"
assert_contains "install failed (continuing)" "$OUT" "failed mise install is reported and skipped"
assert_contains "No AI CLIs installed" "$OUT" "nothing installed warning"
assert_file_not_exists "$CACHE" "status cache invalidated after installs"

# ── `dot ai tools`: gum "Choose which to install" with a selection ──
test_start "ai_tools_choose_which_via_gum"
GUM_MISSING="Choose which to install" GUM_PICK='Codex CLI\nOpenCode' \
  run_ai "$GUM:$MISE:$BASE_PATH" ai tools
assert_equals 0 "$RC" "choose-which flow exits 0"
assert_file_contains "$CALLS" "npm:@openai/codex@latest" "picked codex installed"
assert_file_contains "$CALLS" "npm:opencode-ai@latest" "picked opencode installed"
if grep -q 'aider' "$CALLS"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unpicked provider must not be installed"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: unpicked provider not installed"
fi

# ── `dot ai tools`: gum "Choose which" but nothing picked ──────────
test_start "ai_tools_choose_nothing_via_gum"
GUM_MISSING="Choose which to install" GUM_PICK="" \
  run_ai "$GUM:$MISE:$BASE_PATH" ai tools
assert_equals 0 "$RC" "empty pick exits 0"
if grep -q 'mise use' "$CALLS"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: nothing should be installed"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: nothing installed"
fi

# ── `dot ai tools`: mise present, no gum → tips only ───────────────
test_start "ai_tools_missing_without_gum"
run_ai "$MISE:$BASE_PATH" ai tools
assert_equals 0 "$RC" "no-gum tips exit 0"
assert_contains "Install missing providers: mise install" "$OUT" "mise tip"
assert_contains "Or individually: mise use -g <package>@latest" "$OUT" "per-package tip"

# ── `dot ai tools`: something installed, no gum → launcher tip ─────
mk_tool claude
test_start "ai_tools_installed_without_gum"
run_ai "$TOOLS:$BASE_PATH" ai tools
assert_equals 0 "$RC" "launcher tip exits 0"
assert_contains "Install gum for interactive launcher" "$OUT" "gum launcher tip"
assert_file_exists "$CACHE" "status cache written"
assert_file_contains "$CACHE" "claude" "cache lists the probed tool"

# ── `dot ai tools install <tool>` verb ─────────────────────────────
test_start "ai_tools_install_verb"
run_ai "$TOOLS:$MISE:$BASE_PATH" ai tools install codex
assert_file_contains "$CALLS" "npm:@openai/codex@latest" "tools install routes to cmd_ai_install"

# ── Bridge: run log hook fires after a one-shot ────────────────────
test_start "ai_bridge_logs_run"
run_ai "$TOOLS:$BASE_PATH" ai claude "hello there"
assert_equals 0 "$RC" "one-shot exits 0"
assert_contains "claude-ran" "$OUT" "claude invoked"
assert_file_contains "$CALLS" "ai-log claude" "run logged with provider"
assert_file_contains "$CALLS" " 0 " "run logged with exit code 0"

# ── Bridge: --help, bad --style, kiro alias, raw + style ───────────
test_start "ai_bridge_help"
run_ai "$TOOLS:$BASE_PATH" codex --help
assert_equals 0 "$RC" "bridge --help exits 0"
assert_contains "Usage: dot ai" "$OUT" "bridge usage shown"
assert_contains "Available styles:" "$OUT" "styles listed"

test_start "ai_bridge_missing_style"
run_ai "$TOOLS:$BASE_PATH" ai claude --style no-such-style "hi"
assert_equals 1 "$RC" "unknown style exits 1"
assert_contains "Pattern not found" "$OUT" "unknown style reported"

mk_tool kiro-cli
test_start "ai_bridge_kiro_alias"
run_ai "$TOOLS:$BASE_PATH" kiro "hi"
assert_equals 0 "$RC" "kiro alias exits 0"
assert_contains "kiro-cli-ran" "$OUT" "kiro resolves to kiro-cli"

test_start "ai_bridge_raw_with_style"
DOT_AI_RAW=1 run_ai "$TOOLS:$BASE_PATH" ai claude --style architect "hi"
assert_equals 0 "$RC" "raw styled one-shot exits 0"
assert_contains "claude-ran" "$OUT" "claude invoked in raw mode"

# ── Bridge: tool missing → install prompts ─────────────────────────
test_start "ai_bridge_missing_tool_plain_prompt_declines"
run_ai "$MISE:$BASE_PATH" ai codex "hi"
assert_equals 1 "$RC" "declined install exits 1"
assert_contains "Install codex via mise (npm:@openai/codex)? [y/N]" "$OUT" "plain prompt shown"
assert_contains "install with: mise use -g npm:@openai/codex@latest" "$OUT" "install hint"

test_start "ai_bridge_missing_tool_gum_confirm_installs"
run_ai "$GUM:$MISE:$BASE_PATH" ai codex "hi"
assert_file_contains "$CALLS" "mise use -g npm:@openai/codex@latest" "gum confirm triggers mise install"

test_start "ai_bridge_missing_tool_install_fails"
MISE_FAIL_PKG="npm:@openai/codex" run_ai "$GUM:$MISE:$BASE_PATH" ai codex "hi"
assert_equals 1 "$RC" "failed install exits 1"
assert_contains "installation failed" "$OUT" "failure reported"

test_start "ai_bridge_missing_tool_no_mise"
run_ai "$NOMISE:/usr/bin:/bin" ai codex "hi"
assert_equals 1 "$RC" "no mise exits 1"
assert_contains "not installed and mise not available" "$OUT" "no-mise message"

test_start "ai_bridge_missing_tool_without_package"
run_ai "$MISE:$BASE_PATH" ai goose "hi"
assert_equals 1 "$RC" "tool without a mise package exits 1"
assert_contains "not installed and mise not available" "$OUT" "falls to the generic message"

# ── Deprecated verbs ───────────────────────────────────────────────
test_start "ai_deprecated_local_without_proxy"
run_ai "$BASE_PATH" ai local
assert_equals 1 "$RC" "ai local without dot-ai-proxy exits 1"
assert_contains "deprecated" "$OUT" "deprecation hint"

test_start "ai_deprecated_ai_query"
run_ai "$TOOLS:$BASE_PATH" ai-query "2+2"
assert_contains "use: dot ai ask" "$OUT" "ai-query deprecation hint"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
