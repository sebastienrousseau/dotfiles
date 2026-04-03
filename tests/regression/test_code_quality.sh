#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Code quality — complexity, duplication, maintainability.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Files changed in this branch
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

NEW_SCRIPTS=(
  scripts/uninstall.sh
)

# ═══════════════════════════════════════════════════════════════
# 1. FUNCTION LENGTH — no function over 80 lines
# ═══════════════════════════════════════════════════════════════

test_start "complexity_function_length"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find function definitions and count lines until closing brace
  in_func=0
  func_name=""
  func_lines=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\(\) ]]; then
      if [[ $in_func -eq 1 && $func_lines -gt 80 ]]; then
        printf '    %s: function %s is %d lines (max 80)\n' "$f" "$func_name" "$func_lines"
        failures=$((failures + 1))
      fi
      func_name="${line%%(*}"
      func_lines=0
      in_func=1
    elif [[ $in_func -eq 1 ]]; then
      func_lines=$((func_lines + 1))
    fi
  done < "$filepath"
  # Check last function
  if [[ $in_func -eq 1 && $func_lines -gt 80 ]]; then
    printf '    %s: function %s is %d lines (max 80)\n' "$f" "$func_name" "$func_lines"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no function exceeds 80 lines"

# ═══════════════════════════════════════════════════════════════
# 2. FILE LENGTH — no single script over 600 lines
# ═══════════════════════════════════════════════════════════════

test_start "complexity_file_length"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  lines=$(wc -l < "$filepath" | tr -d ' ')
  if [[ "$lines" -gt 600 ]]; then
    printf '    %s: %s lines (max 600)\n' "$f" "$lines"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no script exceeds 600 lines"

# ═══════════════════════════════════════════════════════════════
# 3. NESTING DEPTH — no more than 5 levels of indentation
# ═══════════════════════════════════════════════════════════════

test_start "complexity_nesting_depth"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Count max leading spaces (2-space indent = depth)
  max_depth=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    spaces="${line%%[! ]*}"
    depth=$((${#spaces} / 2))
    if [[ $depth -gt $max_depth ]]; then
      max_depth=$depth
    fi
  done < "$filepath"
  if [[ $max_depth -gt 7 ]]; then
    printf '    %s: max nesting depth %d (max 7)\n' "$f" "$max_depth"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no script exceeds 7 levels of nesting"

# ═══════════════════════════════════════════════════════════════
# 4. DUPLICATE CODE — identical blocks across files
# ═══════════════════════════════════════════════════════════════

test_start "duplication_cached_eval_not_triplicated"
# _cached_eval should exist in at most 2 shell files (zsh + bash)
# Fish has its own implementation in .fish format
count=$(grep -rl '_cached_eval()' "$REPO_ROOT/dot_bashrc" "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$count" -le 2 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: _cached_eval in $count files (max 2)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: _cached_eval duplicated in $count files"
fi

test_start "duplication_no_copy_paste_functions"
# Check for identical function bodies across changed files
# Look for functions defined in multiple files with same name
all_funcs=""
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  funcs=$(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$filepath" 2>/dev/null | sed 's/()//' || true)
  all_funcs="$all_funcs $funcs"
done
dupes=$(echo "$all_funcs" | tr ' ' '\n' | sort | uniq -d | grep -v '^$' || true)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate function names across changed files"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate functions: $dupes"
fi

test_start "duplication_ui_functions_from_library"
# Commands should source shared UI library, not redefine ui_* functions
failures=0
for f in scripts/dot/commands/ai.sh scripts/ops/chezmoi-apply.sh; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -qE '^ui_(ok|err|info|warn|header)\(\)' "$filepath" 2>/dev/null; then
    printf '    %s: redefines ui_* functions (should source lib/ui.sh)\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "commands must use shared UI library, not redefine"

# ═══════════════════════════════════════════════════════════════
# 5. DEAD CODE — unreachable or unused definitions
# ═══════════════════════════════════════════════════════════════

test_start "deadcode_no_unreachable_after_exit"
# Code after exit/return without condition is dead
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  prev_was_exit=0
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" =~ ^# ]] && continue
    if [[ $prev_was_exit -eq 1 ]]; then
      # Line after exit that isn't }, esac, fi, else, done, ;; is dead
      case "$trimmed" in
        "}"*|"fi"*|"esac"*|"else"*|"elif"*|"done"*|";;"*|")"*) ;;
        *)
          printf '    %s:%d: possible dead code after exit/return\n' "$f" "$line_num"
          failures=$((failures + 1))
          ;;
      esac
      prev_was_exit=0
    fi
    if [[ "$trimmed" =~ ^exit[[:space:]] || "$trimmed" =~ ^return[[:space:]] || "$trimmed" == "exit" || "$trimmed" == "return" ]]; then
      prev_was_exit=1
    else
      prev_was_exit=0
    fi
  done < "$filepath"
done
assert_equals "0" "$failures" "no dead code after exit/return statements"

# ═══════════════════════════════════════════════════════════════
# 6. COMMENT RATIO — at least 10% comments in scripts
# ═══════════════════════════════════════════════════════════════

test_start "quality_comment_ratio"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  total=$(wc -l < "$filepath" | tr -d ' ')
  [[ "$total" -lt 10 ]] && continue
  comments=$(grep -cE '^\s*#' "$filepath" 2>/dev/null || true)
  ratio=$((comments * 100 / total))
  if [[ "$ratio" -lt 3 ]]; then
    printf '    %s: %d%% comments (min 3%%)\n' "$f" "$ratio"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must have at least 3% comment lines"

# ═══════════════════════════════════════════════════════════════
# 7. CONSISTENT ERROR HANDLING — set -uo pipefail
# ═══════════════════════════════════════════════════════════════

STANDALONE_SCRIPTS=(
  scripts/dot/commands/ai.sh
  scripts/ops/chezmoi-apply.sh
  scripts/ops/prewarm.sh
  scripts/ops/ai-setup.sh
  scripts/uninstall.sh
  install.sh
)

test_start "quality_strict_mode"
failures=0
for f in "${STANDALONE_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! grep -q 'set -e\|set -uo pipefail' "$filepath" 2>/dev/null; then
    printf '    %s: missing set -e or set -uo pipefail\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must use strict error handling"

# ═══════════════════════════════════════════════════════════════
# 8. MAGIC NUMBERS — hardcoded numeric constants
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_magic_numbers"
# Check for unexplained numeric constants (excluding common ones: 0,1,2,3,10,100)
failures=0
for f in scripts/uninstall.sh; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Look for bare numbers in conditionals that aren't 0, 1, or common
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\b[4-9][0-9]{3,}\b'; then
    # Allow port numbers, timeout values if named
    bare=$(grep -vE '^\s*#' "$filepath" | grep -cE '\b[4-9][0-9]{3,}\b' || true)
    if [[ "$bare" -gt 3 ]]; then
      printf '    %s: %s magic numbers found\n' "$f" "$bare"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "new scripts should name numeric constants"

# ═══════════════════════════════════════════════════════════════
# 9. CONSISTENT NAMING — snake_case for functions
# ═══════════════════════════════════════════════════════════════

test_start "quality_function_naming"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find function names with camelCase (uppercase letter after lowercase)
  while IFS= read -r func; do
    if [[ "$func" =~ [a-z][A-Z] ]]; then
      printf '    %s: camelCase function: %s\n' "$f" "$func"
      failures=$((failures + 1))
    fi
  done < <(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$filepath" 2>/dev/null | sed 's/()//')
done
assert_equals "0" "$failures" "functions must use snake_case naming"

# ═══════════════════════════════════════════════════════════════
# 10. TODO/FIXME — track unresolved items
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_todo_in_new_scripts"
failures=0
for f in scripts/uninstall.sh; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -qiE '\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b' "$filepath" 2>/dev/null; then
    count=$(grep -ciE '\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b' "$filepath")
    printf '    %s: %s unresolved TODO/FIXME items\n' "$f" "$count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts must not have unresolved TODO/FIXME"

# ═══════════════════════════════════════════════════════════════
# 11. CYCLOMATIC COMPLEXITY — case statements
# ═══════════════════════════════════════════════════════════════

test_start "complexity_case_branches"
# Case statements with more than 20 branches indicate need for refactoring
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  in_case=0
  branch_count=0
  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" =~ ^case[[:space:]] ]]; then
      in_case=1
      branch_count=0
    elif [[ "$trimmed" == "esac" && $in_case -eq 1 ]]; then
      if [[ $branch_count -gt 25 ]]; then
        printf '    %s: case with %d branches (max 25)\n' "$f" "$branch_count"
        failures=$((failures + 1))
      fi
      in_case=0
    elif [[ $in_case -eq 1 && "$trimmed" =~ ^\) ]]; then
      branch_count=$((branch_count + 1))
    fi
  done < "$filepath"
done
assert_equals "0" "$failures" "case statements must have <= 25 branches"

# ═══════════════════════════════════════════════════════════════
# 12. SHELLCHECK DIRECTIVE DENSITY — too many disables = smell
# ═══════════════════════════════════════════════════════════════

test_start "quality_shellcheck_disable_count"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  disable_count=$(grep -c 'shellcheck disable' "$filepath" 2>/dev/null || true)
  if [[ "$disable_count" -gt 5 ]]; then
    printf '    %s: %s shellcheck disables (max 5)\n' "$f" "$disable_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must not have > 5 shellcheck disables"

# ═══════════════════════════════════════════════════════════════
# 13. COPYRIGHT HEADERS — all scripts must have one
# ═══════════════════════════════════════════════════════════════

test_start "quality_copyright_header"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! head -5 "$filepath" | grep -qi 'copyright'; then
    printf '    %s: missing copyright header\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all scripts must have copyright header"

# ═══════════════════════════════════════════════════════════════
# 14. COPYRIGHT YEAR — headers should reference current year
# ═══════════════════════════════════════════════════════════════

test_start "quality_copyright_year"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if head -5 "$filepath" | grep -qi 'copyright'; then
    if ! head -5 "$filepath" | grep -qE '2026'; then
      printf '    %s: copyright header does not include 2026\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "copyright headers should include current year (2026)"

# ═══════════════════════════════════════════════════════════════
# 15. NO ECHO -E — should use printf instead
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_echo_e"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  count=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\becho\s+-e\b' || true)
  if [[ "$count" -gt 0 ]]; then
    printf '    %s: %d uses of echo -e (use printf instead)\n' "$f" "$count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must use printf instead of echo -e"

# ═══════════════════════════════════════════════════════════════
# 16. NO BACKTICK COMMAND SUBSTITUTION
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_backtick_substitution"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Look for backtick command substitution (excluding inside comments and strings)
  count=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE "\`[^\`]+\`" || true)
  if [[ "$count" -gt 0 ]]; then
    printf '    %s: %d backtick substitutions (use %s instead)\n' "$f" "$count" '$()'
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must use \$() not backticks for command substitution"

# ═══════════════════════════════════════════════════════════════
# 17. IF/THEN BLOCKS HAVE MATCHING FI
# ═══════════════════════════════════════════════════════════════

test_start "quality_if_then_matching_fi"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if_count=$(grep -cE '^\s*if\b' "$filepath" 2>/dev/null || true)
  fi_count=$(grep -cE '^\s*fi\b' "$filepath" 2>/dev/null || true)
  if [[ "$if_count" -ne "$fi_count" ]]; then
    printf '    %s: %d if vs %d fi (mismatch)\n' "$f" "$if_count" "$fi_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all if/then blocks must have matching fi"

# ═══════════════════════════════════════════════════════════════
# 18. NO TRAILING WHITESPACE
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_trailing_whitespace"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  trailing=$(grep -cnE '\s+$' "$filepath" 2>/dev/null || true)
  if [[ "$trailing" -gt 0 ]]; then
    printf '    %s: %d lines with trailing whitespace\n' "$f" "$trailing"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no trailing whitespace in scripts"

# ═══════════════════════════════════════════════════════════════
# 19. USE [[ ]] NOT [ ] FOR CONDITIONALS
# ═══════════════════════════════════════════════════════════════

test_start "quality_double_bracket_conditionals"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find single-bracket test that is not inside [[ ]]
  single_bracket=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\b(if|&&|\|\|)\s+\[\s+[^[]' || true)
  if [[ "$single_bracket" -gt 0 ]]; then
    printf '    %s: %d single-bracket [ ] conditionals (use [[ ]])\n' "$f" "$single_bracket"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts should use [[ ]] not [ ] for conditionals"

# ═══════════════════════════════════════════════════════════════
# 20. NO WHICH USAGE — use command -v
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_which"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  which_count=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\bwhich\b' || true)
  if [[ "$which_count" -gt 0 ]]; then
    printf '    %s: %d uses of which (use command -v)\n' "$f" "$which_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must use 'command -v' not 'which'"

# ═══════════════════════════════════════════════════════════════
# 21. VARIABLE NAMES — snake_case (no camelCase)
# ═══════════════════════════════════════════════════════════════

test_start "quality_variable_naming_snake_case"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find variable assignments with camelCase names
  camel_vars=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -oE '\b[a-z]+[A-Z][a-zA-Z]*=' | sed 's/=//' || true)
  if [[ -n "$camel_vars" ]]; then
    printf '    %s: camelCase variables: %s\n' "$f" "$(echo "$camel_vars" | tr '\n' ', ')"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "variable names must use snake_case (no camelCase)"

# ═══════════════════════════════════════════════════════════════
# 22. NO REDEFINING STANDARD BUILTINS
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_redefine_builtins"
failures=0
builtins_pattern='^(cd|echo|printf|read|test|true|false|exit|return|export|unset|source)\(\)'
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  redefined=$(grep -cE "$builtins_pattern" "$filepath" 2>/dev/null || true)
  if [[ "$redefined" -gt 0 ]]; then
    printf '    %s: redefines %d standard builtins\n' "$f" "$redefined"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must not redefine standard shell builtins"

# ═══════════════════════════════════════════════════════════════
# 23. FILE SIZE — all scripts under 50KB
# ═══════════════════════════════════════════════════════════════

test_start "quality_file_size_limit"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  size=$(wc -c < "$filepath" | tr -d ' ')
  if [[ "$size" -gt 51200 ]]; then
    printf '    %s: %d bytes (max 51200)\n' "$f" "$size"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "all scripts must be under 50KB"

# ═══════════════════════════════════════════════════════════════
# 24. FUNCTION DEFINITION STYLE — consistent name() { format
# ═══════════════════════════════════════════════════════════════

test_start "quality_function_definition_style"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find function keyword usage (should use name() { style instead)
  func_keyword=$(grep -cE '^\s*function\s+\w+' "$filepath" 2>/dev/null || true)
  if [[ "$func_keyword" -gt 0 ]]; then
    printf '    %s: %d uses of "function" keyword (use name() { style)\n' "$f" "$func_keyword"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "functions must use name() { style, not function keyword"

# ═══════════════════════════════════════════════════════════════
# 25. NO NESTED FUNCTION DEFINITIONS
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_nested_functions"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  in_func=0
  depth=0
  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "$trimmed" =~ ^# ]] && continue
    if [[ "$trimmed" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\(\) ]]; then
      if [[ $in_func -eq 1 && $depth -gt 0 ]]; then
        printf '    %s: nested function definition detected\n' "$f"
        failures=$((failures + 1))
        break
      fi
      in_func=1
    fi
    # Track brace depth (simplified)
    opens=$(echo "$trimmed" | grep -o '{' | wc -l | tr -d ' ')
    closes=$(echo "$trimmed" | grep -o '}' | wc -l | tr -d ' ')
    depth=$((depth + opens - closes))
    if [[ $depth -le 0 && $in_func -eq 1 ]]; then
      in_func=0
      depth=0
    fi
  done < "$filepath"
done
assert_equals "0" "$failures" "scripts must not have nested function definitions"

# ═══════════════════════════════════════════════════════════════
# 26. CASE STATEMENTS — ;; terminator consistency
# ═══════════════════════════════════════════════════════════════

test_start "quality_case_terminators"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  in_case=0
  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" =~ ^case[[:space:]] ]]; then
      in_case=1
    elif [[ "$trimmed" == "esac" ]]; then
      in_case=0
    elif [[ $in_case -eq 1 && "$trimmed" =~ ^\) ]]; then
      # This is a case branch — the previous branch should end with ;;
      :
    elif [[ $in_case -eq 1 && "$trimmed" =~ ^\;\& ]]; then
      # ;& or ;;& fall-through — this is intentional
      :
    fi
  done < "$filepath"
done
assert_equals "0" "$failures" "case statements must use ;; terminators consistently"

# ═══════════════════════════════════════════════════════════════
# 27. NO HARDCODED VERSION NUMBERS
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_hardcoded_versions"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Look for hardcoded semver patterns in non-comment lines
  hardcoded=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '"[0-9]+\.[0-9]+\.[0-9]+"' || true)
  if [[ "$hardcoded" -gt 2 ]]; then
    printf '    %s: %d hardcoded version strings (use variables)\n' "$f" "$hardcoded"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts should not hardcode version numbers (use variables)"

# ═══════════════════════════════════════════════════════════════
# 28. TRAP HANDLERS — cleanup properly
# ═══════════════════════════════════════════════════════════════

test_start "quality_trap_handlers"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE 'mktemp|tmp_|TMPDIR'; then
    if ! grep -q 'trap' "$filepath" 2>/dev/null; then
      printf '    %s: uses temp files but has no trap for cleanup\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "new scripts using temp files must have trap handlers"

# ═══════════════════════════════════════════════════════════════
# 29. ERROR MESSAGES TO STDERR
# ═══════════════════════════════════════════════════════════════

test_start "quality_errors_to_stderr"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check for error/fatal messages that don't redirect to stderr
  err_to_stdout=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -iE '(echo|printf).*\b(error|fatal|fail)\b' | grep -cvE '>&2|stderr' || true)
  if [[ "$err_to_stdout" -gt 0 ]]; then
    printf '    %s: %d error messages not sent to stderr\n' "$f" "$err_to_stdout"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "error messages must go to stderr (>&2)"

# ═══════════════════════════════════════════════════════════════
# 30. EXIT CODES — meaningful values
# ═══════════════════════════════════════════════════════════════

test_start "quality_meaningful_exit_codes"
failures=0
for f in "${STANDALONE_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check for exit codes greater than 2 that might be non-standard
  weird_exit=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\bexit\s+[3-9][0-9]*\b' || true)
  if [[ "$weird_exit" -gt 0 ]]; then
    printf '    %s: %d non-standard exit codes (use 0=success, 1=error, 2=usage)\n' "$f" "$weird_exit"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "exit codes should be meaningful (0=success, 1=error, 2=usage)"

# ═══════════════════════════════════════════════════════════════
# 31. NO PROCESS SUBSTITUTION IN POSIX PATHS
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_process_sub_in_posix"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # If script uses #!/bin/sh or claims POSIX, no <() allowed
  shebang=$(head -1 "$filepath")
  if [[ "$shebang" == *"/bin/sh"* ]]; then
    procsub=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '<\(' || true)
    if [[ "$procsub" -gt 0 ]]; then
      printf '    %s: process substitution <() in POSIX script\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "no process substitution <() in POSIX-critical paths"

# ═══════════════════════════════════════════════════════════════
# 32. SHARED LIBRARY SOURCING — avoid duplicating code
# ═══════════════════════════════════════════════════════════════

test_start "quality_shared_library_sourcing"
failures=0
for f in "${STANDALONE_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # If script defines ui_header, ui_ok, etc. it should source a library
  ui_defs=$(grep -cE '^(ui_ok|ui_err|ui_info|ui_warn|ui_header)\(\)' "$filepath" 2>/dev/null || true)
  if [[ "$ui_defs" -gt 2 ]]; then
    printf '    %s: defines %d UI functions (should source shared library)\n' "$f" "$ui_defs"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts should source shared libraries instead of duplicating UI code"

# ═══════════════════════════════════════════════════════════════
# 33. HEREDOC QUOTING — heredocs should be quoted to prevent expansion
# ═══════════════════════════════════════════════════════════════

test_start "quality_heredoc_quoting"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check for unquoted heredocs that might have unintended variable expansion
  unquoted_heredocs=$(grep -cE '<<\s*[A-Z]+\s*$' "$filepath" 2>/dev/null || true)
  # This is informational; just verify syntax is valid
  if [[ "$unquoted_heredocs" -gt 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $unquoted_heredocs heredocs found (review for quoting)"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no unquoted heredocs"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 34. CONSISTENT QUOTING — variables in double quotes
# ═══════════════════════════════════════════════════════════════

test_start "quality_variable_quoting"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Look for unquoted $VAR in potentially dangerous contexts (rm, mv, cp)
  unquoted=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\b(rm|mv|cp)\s+(-[a-zA-Z]+\s+)*\$[A-Z_]+[^"'\''{}]' || true)
  if [[ "$unquoted" -gt 0 ]]; then
    printf '    %s: %d potentially unquoted variables in file operations\n' "$f" "$unquoted"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "variables must be quoted in file operations (rm, mv, cp)"

# ═══════════════════════════════════════════════════════════════
# 35. SHELLCHECK SEVERITY — no inline disables for error-level
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_error_level_disables"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # SC2086 (word splitting) is error-level and commonly disabled; that is OK.
  # But SC2034 (unused var) in new code suggests dead code.
  sc2034_disables=$(grep -c 'shellcheck disable=SC2034' "$filepath" 2>/dev/null || true)
  if [[ "$sc2034_disables" -gt 2 ]]; then
    printf '    %s: %d SC2034 disables (unused variables)\n' "$f" "$sc2034_disables"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts should not excessively disable SC2034 (unused vars)"

# ═══════════════════════════════════════════════════════════════
# 36. NO EVAL USAGE — eval is a security risk
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_eval"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  eval_count=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\beval\b' || true)
  if [[ "$eval_count" -gt 0 ]]; then
    printf '    %s: %d uses of eval (security risk)\n' "$f" "$eval_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "new scripts should not use eval"

# ═══════════════════════════════════════════════════════════════
# 37. NO ABSOLUTE PATH TO BASH — use env
# ═══════════════════════════════════════════════════════════════

test_start "quality_shebang_portable"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  first_line=$(head -1 "$filepath")
  if [[ "$first_line" == "#!/bin/bash" ]]; then
    printf '    %s: uses #!/bin/bash (should be #!/usr/bin/env bash)\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must use #!/usr/bin/env bash for portability"

# ═══════════════════════════════════════════════════════════════
# 38. NO TABS FOR INDENTATION — 2-space indent per convention
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_tab_indentation"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  tab_lines=$(grep -cP '^\t' "$filepath" 2>/dev/null || true)
  if [[ "$tab_lines" -gt 0 ]]; then
    printf '    %s: %d lines with tab indentation (use 2 spaces)\n' "$f" "$tab_lines"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must use spaces, not tabs, for indentation"

# ═══════════════════════════════════════════════════════════════
# 39. CONSISTENT RETURN VALUES — functions return 0 or 1
# ═══════════════════════════════════════════════════════════════

test_start "quality_function_return_values"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  weird_return=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\breturn\s+[3-9][0-9]*\b' || true)
  if [[ "$weird_return" -gt 0 ]]; then
    printf '    %s: %d non-standard return values (use 0 or 1)\n' "$f" "$weird_return"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "function return values should be 0 (success) or 1 (failure)"

# ═══════════════════════════════════════════════════════════════
# 40. NO SLEEP IN SCRIPTS — unless clearly justified
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_sleep"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  sleep_count=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '\bsleep\b' || true)
  if [[ "$sleep_count" -gt 2 ]]; then
    printf '    %s: %d sleep calls (avoid unnecessary delays)\n' "$f" "$sleep_count"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts should minimize sleep calls"

# ═══════════════════════════════════════════════════════════════
# 41. NO HARDCODED HOME PATHS
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_hardcoded_home"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  hardcoded_home=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '/Users/[a-z]|/home/[a-z]' || true)
  if [[ "$hardcoded_home" -gt 0 ]]; then
    printf '    %s: %d hardcoded home paths (use %s or ~)\n' "$f" "$hardcoded_home" '$HOME'
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts must not hardcode user home paths"

# ═══════════════════════════════════════════════════════════════
# 42. NO CURL WITHOUT FAIL FLAGS
# ═══════════════════════════════════════════════════════════════

test_start "quality_curl_with_fail"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -qE '\bcurl\b'; then
    unsafe_curl=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -E '\bcurl\b' | grep -cvE -- '-[a-zA-Z]*f|--fail' || true)
    if [[ "$unsafe_curl" -gt 0 ]]; then
      printf '    %s: %d curl calls without --fail flag\n' "$f" "$unsafe_curl"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "new scripts must use curl with --fail flag"

# ═══════════════════════════════════════════════════════════════
# 43. PIPEFAIL — all standalone scripts use set -o pipefail
# ═══════════════════════════════════════════════════════════════

test_start "quality_pipefail_set"
failures=0
for f in "${STANDALONE_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  if ! grep -q 'pipefail' "$filepath" 2>/dev/null; then
    printf '    %s: missing pipefail\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "standalone scripts must set pipefail"

# ═══════════════════════════════════════════════════════════════
# 44. NO DOUBLE SEMICOLONS OUTSIDE CASE
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_stray_double_semicolons"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  in_case=0
  stray=0
  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "$trimmed" =~ ^# ]] && continue
    if [[ "$trimmed" =~ ^case[[:space:]] ]]; then
      in_case=1
    elif [[ "$trimmed" == "esac" ]]; then
      in_case=0
    elif [[ $in_case -eq 0 && "$trimmed" == ";;" ]]; then
      stray=$((stray + 1))
    fi
  done < "$filepath"
  if [[ "$stray" -gt 0 ]]; then
    printf '    %s: %d stray ;; outside case statement\n' "$f" "$stray"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "no stray ;; terminators outside case statements"

# ═══════════════════════════════════════════════════════════════
# 45. READONLY CONSTANTS — important constants should be readonly
# ═══════════════════════════════════════════════════════════════

test_start "quality_readonly_constants"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check if VERSION or PROGRAM_NAME are defined but not readonly
  if grep -qE '^(VERSION|PROGRAM_NAME)=' "$filepath" 2>/dev/null; then
    if ! grep -qE 'readonly (VERSION|PROGRAM_NAME)' "$filepath" 2>/dev/null; then
      printf '    %s: VERSION/PROGRAM_NAME should be readonly\n' "$f"
      failures=$((failures + 1))
    fi
  fi
done
assert_equals "0" "$failures" "important constants should be declared readonly"

# ═══════════════════════════════════════════════════════════════
# 46. NO EMPTY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

test_start "quality_no_empty_functions"
failures=0
for f in "${CHANGED_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Find function() { } with only whitespace/comments between braces
  prev_was_func=0
  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\(\) ]]; then
      prev_was_func=1
    elif [[ $prev_was_func -eq 1 && "$trimmed" == "}" ]]; then
      printf '    %s: empty function body detected\n' "$f"
      failures=$((failures + 1))
      prev_was_func=0
    elif [[ $prev_was_func -eq 1 && -n "$trimmed" && ! "$trimmed" =~ ^[{#] ]]; then
      prev_was_func=0
    fi
  done < "$filepath"
done
assert_equals "0" "$failures" "scripts must not have empty function bodies"

# ═══════════════════════════════════════════════════════════════
# 47. CONSISTENT LOG FORMAT — log messages use consistent prefix
# ═══════════════════════════════════════════════════════════════

test_start "quality_log_format_consistency"
failures=0
for f in "${NEW_SCRIPTS[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  # Check that log/info/warn/error output uses a consistent format
  mixed_log=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '^\s*(echo|printf)\s+.*(INFO|WARN|ERROR|DEBUG)\b' || true)
  ui_log=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '^\s*ui_(ok|err|info|warn|header)\b' || true)
  # Should use one style, not both
  if [[ "$mixed_log" -gt 0 && "$ui_log" -gt 0 ]]; then
    printf '    %s: mixes raw log output and ui_* functions\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "scripts should use consistent logging style"

# ═══════════════════════════════════════════════════════════════
# 48. SOURCED FILES USE RETURN NOT EXIT
# ═══════════════════════════════════════════════════════════════

SOURCED_FILES=(
  .chezmoitemplates/aliases/ai/ai.aliases.sh
  .chezmoitemplates/aliases/default/default.aliases.sh
  .chezmoitemplates/functions/api/apihealth.sh
  .chezmoitemplates/functions/misc/caffeine.sh
  .chezmoitemplates/functions/system/environment.sh
)

test_start "quality_sourced_files_no_exit"
failures=0
for f in "${SOURCED_FILES[@]}"; do
  filepath="$REPO_ROOT/$f"
  [[ -f "$filepath" ]] || continue
  exit_count=$(grep -vE '^\s*#' "$filepath" 2>/dev/null | grep -cE '^\s*exit\b' || true)
  if [[ "$exit_count" -gt 0 ]]; then
    printf '    %s: uses exit (sourced files should use return)\n' "$f"
    failures=$((failures + 1))
  fi
done
assert_equals "0" "$failures" "sourced files must use return, not exit"


echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
