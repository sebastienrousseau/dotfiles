#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# update_programming_tools (the update aliases) end to end, with a
# recording stub for every tool it drives.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UPDATE="$REPO_ROOT/defaults/.chezmoitemplates/aliases/update/update.aliases.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stub" "$WORK/base"
printf '#!/bin/sh\necho "$(basename "$0") $*" >>"$CALLS"\n[ -n "${OUT:-}" ] && printf "%%s\\n" "$OUT"\nexit "${RC:-0}"\n' >"$WORK/stub/tool"
chmod +x "$WORK/stub/tool"
# Only the stubs and the few real utilities the functions use, so no
# installed npm, gem or brew on the host can run.
for t in grep basename sed sort; do ln -s "$(PATH=/usr/bin:/bin command -v "$t")" "$WORK/base/$t"; done
N=0
SHELLS="bash"
command -v zsh >/dev/null 2>&1 && SHELLS="bash zsh"

# upt <shell> <tools> [OUT=text] [RC=n] -- [shell code]: run the code
# (default update_programming_tools) with only <tools> (comma list)
# installed; sets OUT_TEXT, D (a fresh working directory) and CALLS_FILE.
upt() {
  local sh="$1" tools="$2" out="" rc=0 code="update_programming_tools; echo rc=\$?" t
  shift 2
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    case "$1" in OUT=*) out="${1#*=}" ;; RC=*) rc="${1#*=}" ;; esac
    shift
  done
  [[ $# -gt 1 ]] && code="$2"
  D="$WORK/c$((++N))"
  mkdir -p "$D/bin"
  for t in ${tools//,/ }; do ln -s "$WORK/stub/tool" "$D/bin/$t"; done
  CALLS_FILE="$D/calls"
  : >"$CALLS_FILE"
  OUT_TEXT="$(cd "$D" && env -i HOME="$D" PATH="$D/bin:$WORK/base" CALLS="$CALLS_FILE" OUT="$out" RC="$rc" \
    "$(command -v "$sh")" -c 'source "$1"; eval "$2"' _ "$UPDATE" "$code" 2>&1)"
}
ALL="npm,pnpm,rustup,cargo,gem,brew,go,deno,code"

for sh in $SHELLS; do
  test_start "${sh}_leaves_no_output_variables_behind"
  upt "$sh" "$ALL" -- 'update_programming_tools >/dev/null; set | grep -c "^[a-z]*_output=" || true'
  assert_equals "0" "$OUT_TEXT" "no *_output globals leak into the interactive shell"

  test_start "${sh}_reports_a_failing_updater_as_failed"
  upt "$sh" "npm,pnpm,rustup,cargo,gem,brew,deno" RC=1
  assert_equals "0" "$(printf '%s\n' "$OUT_TEXT" | grep -c 'updated successfully')" "no success note after a failed update"
  assert_equals "7" "$(printf '%s\n' "$OUT_TEXT" | grep -c 'update failed (exit 1)')" "each failed updater is reported"

  test_start "${sh}_reports_current_and_updated_tools"
  upt "$sh" "npm,deno" OUT="up to date"
  assert_contains "npm global packages are already up to date." "$OUT_TEXT" "npm marker found"
  assert_contains "Deno updated successfully." "$OUT_TEXT" "deno needs its own marker"
  assert_equals "npm update -g;deno upgrade;" "$(tr '\n' ';' <"$CALLS_FILE")" "each updater runs once, in order"

  test_start "${sh}_leaves_the_go_module_in_the_working_directory_alone"
  upt "$sh" "go" -- 'printf "module example.com/p\n" >go.mod; update_programming_tools; echo rc=$?'
  assert_equals "0" "$(grep -c '^go get' "$CALLS_FILE" || true)" "no go get -u all in the caller's project"
  assert_contains "rc=0" "$OUT_TEXT" "still succeeds"

  test_start "${sh}_notes_cleanups_and_extensions_only_when_they_succeed"
  upt "$sh" "gem,brew,code"
  assert_contains "Ruby gems cleanup completed." "$OUT_TEXT" "gem cleanup note"
  assert_contains "Homebrew cleanup completed." "$OUT_TEXT" "brew cleanup note"
  assert_contains "Visual Studio Code extensions updated successfully." "$OUT_TEXT" "extensions note"
  assert_contains "rc=0" "$OUT_TEXT" "all succeeded"
  upt "$sh" "gem,brew,code" RC=2
  assert_equals "0" "$(printf '%s\n' "$OUT_TEXT" | grep -cE 'cleanup completed|extensions updated')" "no note after a failed step"
  assert_contains "rc=2" "$OUT_TEXT" "a failed extension update is the function's status"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
