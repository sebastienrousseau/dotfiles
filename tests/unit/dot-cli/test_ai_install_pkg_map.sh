#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Contract test for lib/dot/ai-install.sh's provider → mise package map.
# `dot ai <tool>` offers a mise install only when _ai_mise_pkg returns a
# package for that binary, so a typo in an arm silently turns into "not
# installed and mise not available". Every arm is asserted here, along
# with the deliberate blanks (providers with native installers) and the
# unknown-binary default.
#
# The library is sourced, never executed: the native installers it also
# defines reach the network and are not called.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output.
exec 21>&2
export BASH_XTRACEFD=21

AI_INSTALL="$REPO_ROOT/lib/dot/ai-install.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "ai_install_library_sources_cleanly_and_is_re_source_guarded"
_out="$("$BASH_BIN" -c '
  set -euo pipefail
  source "$1"
  first="$_DOT_LIB_AI_INSTALL_LOADED"
  source "$1"
  echo "loaded=$first after=$_DOT_LIB_AI_INSTALL_LOADED"
  declare -F _ai_mise_pkg >/dev/null && echo "map-defined"
  declare -F install_claude_native >/dev/null && echo "installers-defined"
' _ "$AI_INSTALL" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "sourcing twice exits 0"
assert_contains "loaded=1 after=1" "$_out" "the re-source guard holds"
assert_contains "map-defined" "$_out" "the package map is available to callers"
assert_contains "installers-defined" "$_out" "the native installers are available to callers"

# _pkg <binary> — the mapped package for one provider binary.
_pkg() {
  "$BASH_BIN" -c 'source "$1"; _ai_mise_pkg "$2"' _ "$AI_INSTALL" "$1" 2>/dev/null
}

test_start "ai_install_maps_every_mise_backed_provider"
while IFS='=' read -r _bin _want; do
  [[ -n "$_bin" ]] || continue
  assert_equals "$_want" "$(_pkg "$_bin")" "$_bin maps to its mise package"
done <<'MAP'
codex=npm:@openai/codex
copilot=npm:@github/copilot
crush=npm:@charmland/crush
aider=pipx:aider-chat
opencode=npm:opencode-ai
sgpt=pipx:shell-gpt
ollama=aqua:ollama/ollama
kiro-cli=kiro-cli
autohand=npm:autohand-cli
vibe=pipx:mistral-vibe
qwen=npm:@qwen-code/qwen-code
zai=npm:@guizmo-ai/zai-cli
MAP

test_start "ai_install_leaves_native_installer_providers_unmapped"
for _bin in goose amp cursor-agent grok agy kimi claude; do
  assert_equals "" "$(_pkg "$_bin")" "$_bin has no mise package (native installer or n/a)"
done

test_start "ai_install_returns_nothing_for_an_unknown_binary"
assert_equals "" "$(_pkg totally-unknown-tool)" "unknown binaries fall through to the default arm"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
