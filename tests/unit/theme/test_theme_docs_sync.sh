#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Docs/code alignment tests. Every dot theme subcommand should appear:
#   * in the case dispatch in scripts/theme/switch.sh
#   * in the man page share/man/man1/dot-theme.1
#   * in all three shell completions (bash / zsh / fish)
#   * in docs/guides/THEMING.md command reference table
#
# When one drifts, the fleet of examples in the docs stops being
# accurate — this test is a cheap alignment ratchet.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/docs_sync_helpers.sh"

SWITCH_SH="$REPO_ROOT/scripts/theme/switch.sh"
MANPAGE="$REPO_ROOT/share/man/man1/dot-theme.1"
BASH_COMP="$REPO_ROOT/share/completions/bash/dot"
ZSH_COMP="$REPO_ROOT/share/completions/zsh/_dot"
FISH_COMP_TMPL="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl"
THEMING_MD="$REPO_ROOT/docs/guides/THEMING.md"

# Runtime-extract the subcommand list from switch.sh's top-level case
# via the shared docs_sync_helpers module. When a new subcommand lands
# in the dispatcher, it auto-joins the ratchet on the next run — no
# manual edit of this file required.
mapfile -t SUBCOMMANDS < <(
  _docs_extract_from_case_block "$SWITCH_SH" | sort -u
)

_check_present() {
  local file="$1" needle="$2" label="$3"
  if grep -qE "$needle" "$file" 2>/dev/null; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s: %s\n' "$CURRENT_TEST" "$label"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: %s missing in %s\n' "$CURRENT_TEST" "$label" "$(basename "$file")"
  fi
}

# ---------------------------------------------------------------------------
# 1. Every subcommand has a case in switch.sh dispatch.
# ---------------------------------------------------------------------------
for sub in "${SUBCOMMANDS[@]}"; do
  test_start "switch_sh_has_case_for_$sub"
  _check_present "$SWITCH_SH" "^  ${sub}\\)|^  ${sub} \\|" "case $sub) in dispatch"
done

# ---------------------------------------------------------------------------
# 2. Every subcommand is documented in the man page.
# ---------------------------------------------------------------------------
for sub in "${SUBCOMMANDS[@]}"; do
  test_start "manpage_documents_$sub"
  # .TP followed by .B <sub> — the .TP tag opens a definition list entry.
  # `sync` is a common word — anchor on "\.B $sub\b" to avoid false hits.
  _check_present "$MANPAGE" "^\.B(R)? \\\\?${sub}\\b|^\.B \\{?\\\\?${sub}\\b" "man .B $sub entry"
done

# ---------------------------------------------------------------------------
# 3. bash completion knows every subcommand.
# ---------------------------------------------------------------------------
test_start "bash_completion_lists_all_subcommands"
missing=()
subline=$(grep 'local subs=' "$BASH_COMP" | head -1)
for sub in "${SUBCOMMANDS[@]}"; do
  [[ "$subline" != *"$sub"* ]] && missing+=("$sub")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: missing %s\n' "$CURRENT_TEST" "${missing[*]}"
fi

# ---------------------------------------------------------------------------
# 4. zsh completion lists every subcommand.
# ---------------------------------------------------------------------------
test_start "zsh_completion_lists_all_subcommands"
missing=()
for sub in "${SUBCOMMANDS[@]}"; do
  # Look for 'sub:description' entries inside the theme_cmds array.
  grep -q "'${sub}:" "$ZSH_COMP" || missing+=("$sub")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: missing %s\n' "$CURRENT_TEST" "${missing[*]}"
fi

# ---------------------------------------------------------------------------
# 5. Fish completion template lists every subcommand.
# ---------------------------------------------------------------------------
test_start "fish_completion_lists_all_subcommands"
missing=()
subline=$(grep '__dot_theme_subs' "$FISH_COMP_TMPL" | head -1)
for sub in "${SUBCOMMANDS[@]}"; do
  [[ "$subline" != *"$sub"* ]] && missing+=("$sub")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: missing %s\n' "$CURRENT_TEST" "${missing[*]}"
fi

# ---------------------------------------------------------------------------
# 6. THEMING.md command reference row for every subcommand.
# ---------------------------------------------------------------------------
test_start "theming_md_lists_every_subcommand"
missing=()
for sub in "${SUBCOMMANDS[@]}"; do
  # Look for `dot theme <sub>` as a table cell — a backtick-prefixed occurrence.
  grep -qE "\`dot theme ${sub}\b" "$THEMING_MD" || missing+=("$sub")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: missing %s\n' "$CURRENT_TEST" "${missing[*]}"
fi

# ---------------------------------------------------------------------------
# 7. dot-theme(1) man page lint. Same shape as the pan-CLI check.
# groff -mandoc -z parses without producing output; any diagnostic on
# stderr indicates a real syntax problem. Skip if neither tool present.
# ---------------------------------------------------------------------------
test_start "dot_theme_1_man_page_parses_cleanly"
if command -v groff >/dev/null 2>&1; then
  _errs="$(groff -mandoc -z "$MANPAGE" 2>&1)"
  if [[ -z "$_errs" ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "$(echo "$_errs" | head -3)"
  fi
elif command -v mandoc >/dev/null 2>&1; then
  _errs="$(mandoc -T lint "$MANPAGE" 2>&1)"
  if [[ -z "$_errs" ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "$(echo "$_errs" | head -3)"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '  \033[0;33m~\033[0m %s (no groff/mandoc — skipped)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
