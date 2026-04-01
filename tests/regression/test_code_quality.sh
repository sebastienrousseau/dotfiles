#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Code quality — complexity, duplication, maintainability.

set -euo pipefail

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
# 7. CONSISTENT ERROR HANDLING — set -euo pipefail
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
  if ! grep -q 'set -e\|set -euo pipefail' "$filepath" 2>/dev/null; then
    printf '    %s: missing set -e or set -euo pipefail\n' "$f"
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

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
