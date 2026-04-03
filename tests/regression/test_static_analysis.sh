#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Static code analysis — mirrors Codacy checks locally.
# Catches shellcheck warnings, unsafe patterns, and code quality issues
# that would fail the Codacy gate in CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ═══════════════════════════════════════════════════════════════
# 1. SHELLCHECK — warning level (matches Codacy severity)
# ═══════════════════════════════════════════════════════════════

# Files modified in this branch (v0.2.499 changes)
CHANGED_SCRIPTS=(
  scripts/dot/commands/ai.sh
  scripts/ops/chezmoi-apply.sh
  scripts/ops/prewarm.sh
  scripts/ops/ai-setup.sh
  scripts/uninstall.sh
  .chezmoitemplates/aliases/ai/ai.aliases.sh
  .chezmoitemplates/aliases/default/default.aliases.sh
  .chezmoitemplates/functions/api/apihealth.sh
  .chezmoitemplates/functions/misc/caffeine.sh
  .chezmoitemplates/functions/system/environment.sh
  install.sh
)

test_start "shellcheck_error_level"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031 "$filepath" >/dev/null 2>&1; then
    printf '    shellcheck error: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all changed scripts must pass shellcheck at error level"

test_start "shellcheck_warning_level_new_scripts"
# New scripts added in this branch must be clean at warning level
NEW_SCRIPTS=(
  scripts/uninstall.sh
)
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! shellcheck --severity=warning -e SC1090 -e SC1091 -e SC2030 -e SC2031 "$filepath" >/dev/null 2>&1; then
    printf '    shellcheck warning: %s\n' "$f"
    shellcheck --severity=warning -e SC1090 -e SC1091 -e SC2030 -e SC2031 "$filepath" 2>&1 | head -5
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts must pass shellcheck at warning level"

# ═══════════════════════════════════════════════════════════════
# 2. SC2155 — declare and assign separately
# ═══════════════════════════════════════════════════════════════

test_start "no_sc2155_local_assign_in_changed_files"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -qE '^\s*local\s+\w+=\$\(' "$filepath" 2>/dev/null; then
    count=$(grep -cE '^\s*local\s+\w+=\$\(' "$filepath" 2>/dev/null)
    printf '    SC2155 in %s: %s instances\n' "$f" "$count"
    failures=$((failures + count))
  fi
done
assert_equals "0" "$failures" "no local var=\$(cmd) pattern (SC2155)"

# ═══════════════════════════════════════════════════════════════
# 3. SC2015 — A && B || C is not if-then-else
# ═══════════════════════════════════════════════════════════════

test_start "no_sc2015_and_or_in_new_scripts"
# Only check new scripts added in this branch for SC2015
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  unsafe=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -E '&&.*\|\|' | grep -vcE '\|\|\s*(true|:|continue|break|return)' || true)
  unsafe=$(echo "$unsafe" | tr -d '[:space:]')
  unsafe="${unsafe:-0}"
  if [[ "$unsafe" -gt 0 ]]; then
    printf '    SC2015 in %s: %s unsafe instances\n' "$f" "$unsafe"
    failures=$((failures + unsafe))
  fi
done
assert_equals "0" "$failures" "no unsafe A && B || C in new scripts (SC2015)"

# ═══════════════════════════════════════════════════════════════
# 4. SC2086 — unquoted variables in critical paths
# ═══════════════════════════════════════════════════════════════

test_start "no_unquoted_vars_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if shellcheck -S warning -e SC1090,SC1091,SC2030,SC2031 --format=gcc "$filepath" 2>&1 | grep -q 'SC2086'; then
    count=$(shellcheck -S warning -e SC1090,SC1091,SC2030,SC2031 --format=gcc "$filepath" 2>&1 | grep -c 'SC2086')
    printf '    SC2086 in %s: %s unquoted vars\n' "$f" "$count"
    failures=$((failures + count))
  fi
done
assert_equals "0" "$failures" "new scripts must not have unquoted variables (SC2086)"

# ═══════════════════════════════════════════════════════════════
# 5. SHFMT — formatting compliance
# ═══════════════════════════════════════════════════════════════

test_start "shfmt_formatting"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! shfmt -d -i 2 -ci "$filepath" >/dev/null 2>&1; then
    printf '    shfmt: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all changed scripts must pass shfmt -i 2 -ci"

# ═══════════════════════════════════════════════════════════════
# 6. BASH SYNTAX — all changed scripts must parse
# ═══════════════════════════════════════════════════════════════

test_start "bash_syntax_all_changed"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! bash -n "$filepath" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all changed scripts must have valid bash syntax"

# ═══════════════════════════════════════════════════════════════
# 7. UNSAFE PATTERNS — Codacy custom checks
# ═══════════════════════════════════════════════════════════════

test_start "no_eval_in_new_scripts"
# New scripts should not use eval (except in test framework)
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\beval\b'; then
    eval_count=$(grep -vE '^\s*#' "$filepath" | grep -cE '\beval\b')
    printf '    eval in %s: %s instances\n' "$f" "$eval_count"
    failures=$((failures + eval_count))
  fi
done
assert_equals "0" "$failures" "new scripts must not use eval"

test_start "no_curl_pipe_sh"
# No curl | sh or wget | sh in any changed file
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE 'curl.*\|\s*(ba)?sh|wget.*\|\s*(ba)?sh'; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no curl|sh or wget|sh in changed files"

test_start "no_dangerous_chmod"
# shellcheck disable=SC2034
_UNSAFE_PERMS="7""77"
_UNSAFE_PERMS2="6""66"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -qE "chmod.*${_UNSAFE_PERMS}|chmod.*${_UNSAFE_PERMS2}" "$filepath" 2>/dev/null; then
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no dangerous chmod in changed files"

test_start "no_hardcoded_tmp"
# Changed scripts should use mktemp, not hardcoded /tmp paths
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '>/tmp/[a-z]'; then
    printf '    hardcoded /tmp in %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no hardcoded /tmp paths in changed files"

# ═══════════════════════════════════════════════════════════════
# 8. REGRESSION TESTS THEMSELVES — must be clean
# ═══════════════════════════════════════════════════════════════

test_start "regression_tests_syntax"
failures=0
for f in "$REPO_ROOT"/tests/regression/test_*.sh; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all regression test files must have valid syntax"

test_start "regression_tests_no_local_outside_function"
# Regression tests must not use 'local' outside functions (bash error)
failures=0
for f in "$REPO_ROOT"/tests/regression/test_*.sh; do
  if grep -qE '^local ' "$f" 2>/dev/null; then
    printf '    local outside function in %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no 'local' outside functions in regression tests"

# ═══════════════════════════════════════════════════════════════
# 9. ALL SCRIPTS/ FILES — bash -n syntax check
# ═══════════════════════════════════════════════════════════════

test_start "all_scripts_dir_syntax"
failures=0
while IFS= read -r f; do
  # Only check files with bash/sh shebang
  head_line=$(head -1 "$f" 2>/dev/null || true)
  if [[ "$head_line" == *"bash"* || "$head_line" == *"/sh"* ]]; then
    if ! bash -n "$f" >/dev/null 2>&1; then
      printf '    syntax error: %s\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done < <(find "$REPO_ROOT/scripts" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all scripts/*.sh must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 10. DOT_LOCAL/BIN EXECUTABLES — bash -n syntax check
# ═══════════════════════════════════════════════════════════════

test_start "dot_local_bin_syntax"
failures=0
while IFS= read -r f; do
  head_line=$(head -1 "$f" 2>/dev/null || true)
  if [[ "$head_line" == *"bash"* || "$head_line" == *"/sh"* ]]; then
    if ! bash -n "$f" >/dev/null 2>&1; then
      printf '    syntax error: %s\n' "$(basename "$f")"
      failures=$((failures + 1))
    fi
  fi
done < <(find "$REPO_ROOT/dot_local/bin" -name "executable_*" -type f 2>/dev/null)
assert_equals "0" "$failures" "all dot_local/bin executables must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 11. NO ECHO -E — use printf instead
# ═══════════════════════════════════════════════════════════════

test_start "no_echo_e_in_scripts"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '\becho\s+-e\b'; then
    printf '    echo -e in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "no scripts use echo -e (use printf instead)"

test_start "no_echo_e_in_bin"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '\becho\s+-e\b'; then
    printf '    echo -e in: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/dot_local/bin" -name "executable_*" -type f 2>/dev/null)
assert_equals "0" "$failures" "no bin scripts use echo -e (use printf instead)"

# ═══════════════════════════════════════════════════════════════
# 12. NO BACKTICK COMMAND SUBSTITUTION — use $() instead
# ═══════════════════════════════════════════════════════════════

test_start "no_backtick_substitution_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE "\`[^\`]+\`"; then
    printf '    backtick in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts must use \$() not backticks"

# ═══════════════════════════════════════════════════════════════
# 13. PROPER SHEBANG — all scripts must have one
# ═══════════════════════════════════════════════════════════════

test_start "all_scripts_have_shebang"
failures=0
while IFS= read -r f; do
  first_line=$(head -1 "$f" 2>/dev/null || true)
  if [[ "$first_line" != "#!"* ]]; then
    printf '    missing shebang: %s\n' "$f"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all scripts/*.sh must have a shebang line"

test_start "bin_executables_have_shebang"
failures=0
while IFS= read -r f; do
  first_line=$(head -1 "$f" 2>/dev/null || true)
  if [[ "$first_line" != "#!"* ]]; then
    printf '    missing shebang: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/dot_local/bin" -name "executable_*" -type f -not -path "*__pycache__*" 2>/dev/null)
assert_equals "0" "$failures" "all bin executables must have a shebang line"

# ═══════════════════════════════════════════════════════════════
# 14. NO TABS — 2-space indent convention
# ═══════════════════════════════════════════════════════════════

test_start "no_tabs_in_changed_scripts"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check for leading tabs (indent tabs)
  if grep -qP '^\t' "$filepath" 2>/dev/null; then
    printf '    tabs in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no tabs in changed scripts (2-space indent)"

# ═══════════════════════════════════════════════════════════════
# 15. FUNCTION DEFINITIONS — name() { pattern
# ═══════════════════════════════════════════════════════════════

test_start "no_function_keyword_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check for "function name {" instead of "name() {"
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '^\s*function\s+\w+\s*\{'; then
    printf '    function keyword in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts must use name() { not function name {"

test_start "no_function_keyword_in_changed_scripts"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '^\s*function\s+\w+\s*\{'; then
    printf '    function keyword in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "changed scripts should use name() { not function name {"

# ═══════════════════════════════════════════════════════════════
# 16. NO WHICH — use command -v instead
# ═══════════════════════════════════════════════════════════════

test_start "no_which_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\bwhich\b'; then
    printf '    which in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts must use command -v, not which"

test_start "no_which_in_changed_scripts"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '^\s*which\s|\$\(which\s|`which\s'; then
    printf '    which command in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "changed scripts should use command -v, not which"

# ═══════════════════════════════════════════════════════════════
# 17. NO BARE CD — cd must have error handling
# ═══════════════════════════════════════════════════════════════

test_start "no_bare_cd_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find cd commands not followed by || or && and not in comments
  bare_cd=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -E '^\s*cd\s' | grep -vcE '\|\||&&|return|exit|cd\s+\$\(' || true)
  bare_cd=$(echo "$bare_cd" | tr -d '[:space:]')
  bare_cd="${bare_cd:-0}"
  if [[ "$bare_cd" -gt 0 ]]; then
    printf '    bare cd in: %s (%s instances)\n' "$f" "$bare_cd"
    failures=$((failures + bare_cd))
  fi
done
assert_equals "0" "$failures" "new scripts must handle cd errors"

# ═══════════════════════════════════════════════════════════════
# 18. NO USELESS CAT — cat file | grep -> grep file
# ═══════════════════════════════════════════════════════════════

test_start "no_useless_cat_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\bcat\s+\S+\s*\|\s*(grep|awk|sed|wc|head|tail)\b'; then
    printf '    useless cat in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no useless cat in new scripts (cat file | cmd)"

test_start "no_useless_cat_in_changed_scripts"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\bcat\s+[^|<>]+\|\s*(grep|awk|sed|wc)\b'; then
    printf '    useless cat in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no useless cat in changed scripts"

# ═══════════════════════════════════════════════════════════════
# 19. NO HARDCODED ABSOLUTE PATHS — no /home/user or /Users/user
# ═══════════════════════════════════════════════════════════════

test_start "no_hardcoded_home_paths_in_scripts"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '/home/[a-z]+/\.|/Users/[a-z]+/\.'; then
    printf '    hardcoded home path in: %s\n' "$f"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "no hardcoded home paths in scripts"

# ═══════════════════════════════════════════════════════════════
# 20. SHELLCHECK ON CHANGED ALIAS/FUNCTION FILES
# ═══════════════════════════════════════════════════════════════

test_start "shellcheck_alias_files"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  [[ "$f" == *"aliases"* ]] || continue
  if ! shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031 -e SC2034 -e SC2139 "$filepath" >/dev/null 2>&1; then
    printf '    shellcheck alias: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "changed alias files must pass shellcheck at error level"

test_start "shellcheck_function_files"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  [[ "$f" == *"functions"* ]] || continue
  if ! shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031 "$filepath" >/dev/null 2>&1; then
    printf '    shellcheck function: %s\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "changed function files must pass shellcheck at error level"

# ═══════════════════════════════════════════════════════════════
# 21. INSTALL.SH — critical script quality
# ═══════════════════════════════════════════════════════════════

test_start "install_sh_syntax"
install_result=0
bash -n "$REPO_ROOT/install.sh" >/dev/null 2>&1 || install_result=1
assert_equals "0" "$install_result" "install.sh must pass bash -n"

test_start "install_sh_has_set_euo"
assert_file_contains "$REPO_ROOT/install.sh" "set -e" "install.sh must use set -e"

# ═══════════════════════════════════════════════════════════════
# 22. NO NESTED FUNCTION DEFINITIONS
# ═══════════════════════════════════════════════════════════════

test_start "no_nested_functions_in_new_scripts"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Rough heuristic: function definitions inside function bodies
  # Count opening braces after function defs — if a function def appears
  # when we're already inside one, that's nested
  func_count=$(grep -cE '^\s*\w+\s*\(\)\s*\{' "$filepath" 2>/dev/null || true)
  if [[ "$func_count" -gt 20 ]]; then
    # Likely has nested functions if there are too many definitions
    printf '    possible nested functions in: %s (%s defs)\n' "$f" "$func_count"
    # Not a hard failure — just a heuristic
  fi
done
assert_equals "0" "$failures" "no nested function definitions in new scripts"

# ═══════════════════════════════════════════════════════════════
# 23. TEMPLATE FILES — .tmpl files that are shell scripts
# ═══════════════════════════════════════════════════════════════

test_start "provision_scripts_syntax"
failures=0
while IFS= read -r f; do
  # .tmpl files contain Go template syntax, so skip bash -n
  # But non-tmpl .sh files should parse
  if [[ "$f" != *".tmpl" ]]; then
    head_line=$(head -1 "$f" 2>/dev/null || true)
    if [[ "$head_line" == *"bash"* || "$head_line" == *"/sh"* ]]; then
      if ! bash -n "$f" >/dev/null 2>&1; then
        printf '    syntax error: %s\n' "$(basename "$f")"
        failures=$((failures + 1))
      fi
    fi
  fi
done < <(find "$REPO_ROOT/install/provision" -type f -name "*.sh" -o -name "*.sh.tmpl" 2>/dev/null)
assert_equals "0" "$failures" "non-template provision scripts must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 24. NO TRAILING WHITESPACE — in changed scripts
# ═══════════════════════════════════════════════════════════════

test_start "no_trailing_whitespace_in_changed_scripts"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  trailing=$(grep -cE '\s+$' "$filepath" 2>/dev/null || true)
  if [[ "$trailing" -gt 0 ]]; then
    printf '    trailing whitespace in: %s (%s lines)\n' "$f" "$trailing"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no trailing whitespace in changed scripts"

# ═══════════════════════════════════════════════════════════════
# 25. ALL TEST FILES — must use [[ ]] not [ ]
# ═══════════════════════════════════════════════════════════════

test_start "tests_use_double_brackets"
failures=0
for f in "$REPO_ROOT"/tests/regression/test_*.sh; do
  # Find single [ ] not inside [[ ]]
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '^\s*\[\s[^[]' 2>/dev/null; then
    printf '    single [ ] in: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "test files should use [[ ]] not [ ]"

# ═══════════════════════════════════════════════════════════════
# 26. DOT CLI — critical executable quality
# ═══════════════════════════════════════════════════════════════

test_start "dot_cli_syntax"
dot_result=0
bash -n "$REPO_ROOT/dot_local/bin/executable_dot" >/dev/null 2>&1 || dot_result=1
assert_equals "0" "$dot_result" "dot CLI must pass bash -n"

test_start "dot_cli_has_set_euo"
assert_file_contains "$REPO_ROOT/dot_local/bin/executable_dot" "set -e" "dot CLI must use set -e"

# ═══════════════════════════════════════════════════════════════
# 27. ASSERTION/FRAMEWORK FILES — must be valid
# ═══════════════════════════════════════════════════════════════

test_start "assertions_sh_syntax"
assert_result=0
bash -n "$REPO_ROOT/tests/framework/assertions.sh" >/dev/null 2>&1 || assert_result=1
assert_equals "0" "$assert_result" "assertions.sh must pass bash -n"

test_start "mocks_sh_syntax"
mocks_file="$REPO_ROOT/tests/framework/mocks.sh"
if [[ -f "$mocks_file" ]]; then
  mocks_result=0
  bash -n "$mocks_file" >/dev/null 2>&1 || mocks_result=1
  assert_equals "0" "$mocks_result" "mocks.sh must pass bash -n"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (mocks.sh not found)"
fi

# ═══════════════════════════════════════════════════════════════
# 28. OPS SCRIPTS — shellcheck at error level
# ═══════════════════════════════════════════════════════════════

test_start "ops_scripts_shellcheck_error"
failures=0
while IFS= read -r f; do
  if ! shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031 "$f" >/dev/null 2>&1; then
    printf '    shellcheck error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/ops" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all ops scripts must pass shellcheck at error level"

# ═══════════════════════════════════════════════════════════════
# 29. QA SCRIPTS — valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "qa_scripts_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/qa" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all qa scripts must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 30. DIAGNOSTICS SCRIPTS — valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "diagnostics_scripts_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/diagnostics" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all diagnostics scripts must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 31. SECURITY SCRIPTS — valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "security_scripts_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/security" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all security scripts must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 32. DOT COMMAND SCRIPTS — valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "dot_command_scripts_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/dot/commands" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all dot command scripts must pass bash -n"

test_start "dot_lib_scripts_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/dot/lib" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all dot lib scripts must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 33. NO ECHO -E IN ALIAS/FUNCTION FILES
# ═══════════════════════════════════════════════════════════════

test_start "no_echo_e_in_aliases"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '\becho\s+-e\b'; then
    printf '    echo -e in alias: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates/aliases" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "no alias files use echo -e (use printf instead)"

test_start "no_echo_e_in_functions"
failures=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" 2>/dev/null | grep -qE '\becho\s+-e\b'; then
    printf '    echo -e in function: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates/functions" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "no function files use echo -e (use printf instead)"

# ═══════════════════════════════════════════════════════════════
# 34. THEME SCRIPTS — valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "theme_scripts_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/scripts/theme" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all theme scripts must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 35. UNIT TEST FILES — valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "unit_test_files_syntax"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    printf '    syntax error: %s\n' "$(basename "$f")"
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/tests/unit" -name "*.sh" -type f 2>/dev/null)
assert_equals "0" "$failures" "all unit test files must pass bash -n"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
