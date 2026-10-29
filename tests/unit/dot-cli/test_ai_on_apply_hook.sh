#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The ai plugin's on-apply hook (P2.2) lists every roster tool and offers
# to install the missing ones. The offer paths (install all, pick, skip, no
# mise) run through `dot apply` in tests/unit/ops/test_chezmoi_apply_phases.sh;
# these cases run the hook directly for what that test cannot reach: the
# list comes from the roster, a tool with no installer is not offered, and
# without gum or a terminal nothing prompts.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/host_path.sh"

HOOK="$REPO_ROOT/plugins/ai/libexec/hooks/on-apply.sh"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-hook.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# shellcheck disable=SC2046
SYS="$(host_path_without "$WORK/sys" gum mise $(bash -c 'source "$1/lib/dot/data/ai-roster.sh"; echo "${AI_ROSTER_BINS[*]}"' _ "$REPO_ROOT"))"
mkdir -p "$WORK/stubs" "$WORK/home"

# stub NAME: a command that logs its arguments to calls.
stub() {
  printf '#!%s\nprintf "%%s\\n" "%s $*" >>"%s/calls"\n' "$REAL_BASH" "$1" "$WORK" >"$WORK/stubs/$1"
  chmod +x "$WORK/stubs/$1"
}
stub claude
stub mise

# hook [VAR=value...]: run the hook; OUT, RC.
hook() {
  : >"$WORK/calls"
  RC=0
  OUT="$(env -i HOME="$WORK/home" PATH="$WORK/stubs:$SYS" TERM=dumb NO_COLOR=1 LANG=C.UTF-8 "$@" \
    "$REAL_BASH" "$HOOK" </dev/null 2>&1)" || RC=$?
}

test_start "the_list_is_the_roster"
hook DOT_HOOK_INTERACTIVE=1
assert_equals "0" "$RC" "the hook exits 0"
for bin in $(bash -c 'source "$1/lib/dot/data/ai-roster.sh"; echo "${AI_ROSTER_BINS[*]}"' _ "$REPO_ROOT"); do
  label="$(bash -c 'source "$1/lib/dot/data/ai-roster.sh"; for r in "${AI_ROSTER_STATUS[@]}"; do IFS="|" read -r _ _ l b _ <<<"$r"; [[ "$b" == "$2" ]] && echo "$l"; done' _ "$REPO_ROOT" "$bin")"
  assert_contains "$label" "$OUT" "$bin is listed as $label"
done

test_start "installed_missing_and_uninstallable_tools_are_told_apart"
assert_contains "✓ Claude Code" "$(tr -s ' ' <<<"$OUT")" "claude, on PATH, is installed"
assert_contains "Codex CLI not installed" "$(tr -s ' ' <<<"$OUT")" "codex is missing"
assert_contains "Mistral Vibe not installed (no installer for this platform)" "$(tr -s ' ' <<<"$OUT")" \
  "vibe has no installer, so it is not offered"

test_start "without_gum_it_prints_how_to_install"
assert_contains "dot ai install" "$OUT" "the tip names the installing command"
assert_equals "" "$(cat "$WORK/calls")" "and nothing runs"

test_start "a_non_interactive_run_never_offers"
stub gum
hook
assert_equals "0:" "$RC:$(cat "$WORK/calls")" "no DOT_HOOK_INTERACTIVE: no menu, no install"

# gum answers the action menu with GUM_CHOICE and the picker with GUM_PICK
# (comma-separated), reading its menu first as real gum does.
{
  printf '#!%s\n' "$REAL_BASH"
  printf 'printf "%%s\\n" "gum $*" >>"%s/calls"\n' "$WORK"
  printf '%s\n' 'cat >/dev/null' \
    'case "$*" in *--no-limit*) printf "%s\n" "${GUM_PICK:-}" | tr "," "\n" ;; *) printf "%s\n" "${GUM_CHOICE:-Skip}" ;; esac'
} >"$WORK/stubs/gum"

test_start "a_pick_installs_only_the_picked_tools"
hook DOT_HOOK_INTERACTIVE=1 GUM_CHOICE="Choose which to install" GUM_PICK="Codex CLI,,Qwen Code"
assert_equals "0" "$RC" "the hook exits 0"
assert_equals "2" "$(grep -c '^mise use -g' "$WORK/calls")" "two installs, the blank pick ignored"
assert_contains "npm:@openai/codex@" "$(cat "$WORK/calls")" "codex"
assert_contains "npm:@qwen-code/qwen-code@" "$(cat "$WORK/calls")" "and qwen"

test_start "without_mise_it_explains_and_succeeds"
rm -f "$WORK/stubs/mise"
hook DOT_HOOK_INTERACTIVE=1 GUM_CHOICE="Install all"
assert_equals "0" "$RC" "a hint is not a failure"
assert_contains "install mise first" "$OUT" "the hint says what to do"
assert_equals "0" "$(grep -c '^gum' "$WORK/calls")" "and no menu is shown"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
