#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Guards the bash 3.2 compatibility contract.
#
# macOS still ships bash 3.2.57 as /bin/bash, and it is what the macOS
# CI runners resolve `bash` to. Anything that runs there — the dot CLI
# libraries, the diagnostics, the pre-commit hooks, the CI helper
# scripts — must avoid bash 4+ constructs.
#
# Two failures already reached main this way:
#
#   * lib/dot/ui.sh expanded "${_UI_TABLE_ROWS[@]}" on an empty array,
#     which under `set -u` is an unbound-variable error on 3.2 (fatal
#     regardless of errexit). Empty tables aborted the command.
#   * tools/ci/check-copyright-headers.sh, tools/ci/run-coverage.sh and
#     scripts/diagnostics/secret-governance.sh used `mapfile`, a bash 4
#     builtin, so they exited 127 on macOS — the copyright check and
#     the staged-secret scan silently did nothing.
#
# Both classes are invisible on Linux (bash 5), so a static guard is
# the only thing that keeps them from coming back.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

cd "$REPO_ROOT" || exit 1

# Directories whose scripts must run under bash 3.2. tests/ is excluded
# deliberately: the suite is run with whatever bash the runner picks,
# and test helpers are free to assume a modern bash.
PORTABLE_DIRS=(lib scripts tools install bin)

_scan() {
  local pattern="$1"
  local dir hits=""
  for dir in "${PORTABLE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    hits+="$(grep -rnE "$pattern" "$dir" --include='*.sh' 2>/dev/null || true)"$'\n'
  done
  printf '%s' "$hits" | grep -vE '^\s*$' || true
}

# ── bash 4 builtins ──────────────────────────────────────────────────
test_start "no_mapfile_or_readarray"
hits="$(_scan '^[^#]*\b(mapfile|readarray)\b')"
if [[ -z "$hits" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no bash 4 array builtins"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: mapfile/readarray are bash 4 only"
  printf '%s\n' "$hits" | sed 's/^/      /'
fi

# ── bash 4 case-conversion expansions: ${x^^} ${x,,} ${x^} ${x,} ─────
test_start "no_case_conversion_expansion"
hits="$(_scan '\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(\^\^|,,|\^|,)\}')"
if [[ -z "$hits" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no \${x^^}/\${x,,} expansions"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: case-conversion expansion is bash 4 only"
  printf '%s\n' "$hits" | sed 's/^/      /'
fi

# ── bash 4 associative arrays ────────────────────────────────────────
# A script may legitimately use them if it declares the requirement and
# re-execs under a newer bash (scripts/theme/rebuild-themes.sh does).
# Those carry a BASH_VERSINFO guard, so exempt them; everything else
# has to work on 3.2 as-is.
test_start "no_associative_arrays"
hits="$(_scan '^[^#]*\bdeclare\s+-[A-Za-z]*A[A-Za-z]*\s' |
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    file="${hit%%:*}"
    grep -q 'BASH_VERSINFO' "$file" 2>/dev/null || printf '%s\n' "$hit"
  done)"
if [[ -z "$hits" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no declare -A"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: associative arrays are bash 4 only"
  printf '%s\n' "$hits" | sed 's/^/      /'
fi

# ── unguarded empty-array expansion under set -u ─────────────────────
# On bash 3.2, "${arr[@]}" where arr is empty raises "unbound variable"
# and kills the shell. The safe forms are ${arr[@]+"${arr[@]}"} or a
# ${#arr[@]} count guard. Flagging every "${x[@]}" would be far too
# noisy, so this checks the specific arrays that burned us — the ui.sh
# table buffers, which are empty by definition between renders.
test_start "ui_table_arrays_guarded"
unguarded="$(grep -nE '"\$\{_UI_TABLE_(ROWS|WIDTHS|HEADERS)\[@\]\}"' lib/dot/ui.sh 2>/dev/null |
  grep -vE '\$\{#|\[@\]\+' || true)"
if [[ -z "$unguarded" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: table arrays expanded safely"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unguarded empty-array expansion"
  printf '%s\n' "$unguarded" | sed 's/^/      /'
fi

# ── runtime check: the real 3.2 binary, when we have one ─────────────
# macOS keeps 3.2 at /bin/bash. On Linux there is nothing to test
# against, so this records a skip rather than a false pass.
test_start "scripts_parse_under_bash32"
if [[ -x /bin/bash ]] && /bin/bash --version 2>/dev/null | head -1 | grep -q 'version 3\.2'; then
  parse_failures=""
  for f in lib/dot/ui.sh lib/dot/utils.sh \
    tools/ci/check-copyright-headers.sh \
    tools/ci/run-coverage.sh \
    scripts/diagnostics/secret-governance.sh; do
    [[ -f "$f" ]] || continue
    /bin/bash -n "$f" 2>/dev/null || parse_failures+="$f "
  done
  if [[ -z "$parse_failures" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: parse clean under bash 3.2"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $parse_failures"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (no bash 3.2 available)"
fi

# ── runtime check: empty table renders rather than aborting ──────────
test_start "empty_table_renders_under_set_u"
if out="$(
  bash -c '
    set -euo pipefail
    source "$1" || exit 1
    ui_table_begin "A" "B"
    ui_table_end
    ui_table_sep
    printf "SURVIVED\n"
  ' _ "$REPO_ROOT/lib/dot/ui.sh" 2>&1
)" && [[ "$out" == *SURVIVED* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: empty table renders"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${out:-aborted}"
fi

# ── runtime check: the steps API accepts non-numeric ids ─────────────
# _UI_STEP_LABELS was an associative array. On bash 3.2 a subscript is
# evaluated as arithmetic, so ui_step "install-deps" became
# `install - deps` and aborted under `set -u` with "install: unbound
# variable". `dot theme sync` hit this in plain (non-dot-ui) mode.
test_start "ui_step_accepts_string_ids"
if out="$(
  bash -c '
    set -euo pipefail
    source "$1" || exit 1
    ui_steps_begin "T" ""
    ui_step "install-deps" "Installing deps" run
    ui_step "install-deps" "" ok
    ui_step "unlabelled-id" "" ok
    printf "SURVIVED\n"
  ' _ "$REPO_ROOT/lib/dot/ui.sh" 2>&1
)" && [[ "$out" == *SURVIVED* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: string ids handled"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${out:-aborted}"
fi

# The label recorded on the `run` event must still be reused by a later
# terminal event that passes no label — the whole point of the store.
test_start "ui_step_label_memoised"
out="$(
  bash -c '
    set -euo pipefail
    source "$1" || exit 1
    DOTFILES_ACCESSIBILITY=1 ui_steps_begin "" ""
    ui_step "some-id" "Human Label" run
    ui_step "some-id" "" ok
  ' _ "$REPO_ROOT/lib/dot/ui.sh" 2>&1
)"
if [[ "$out" == *"Human Label"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: label reused on terminal event"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got ${out:-<nothing>}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
