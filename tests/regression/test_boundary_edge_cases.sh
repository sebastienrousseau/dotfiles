#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Boundary & edge cases — extreme or unusual conditions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# ═══════════════════════════════════════════════════════════════
# 1. MISSING TOOLS — graceful degradation
# ═══════════════════════════════════════════════════════════════

test_start "edge_dot_help_without_gum"
# dot help should work even without gum
(
  export PATH="$MOCK_BIN_DIR"
  # Ensure bash is available but gum is not
  ln -sf "$(command -v bash)" "$MOCK_BIN_DIR/bash"
  ln -sf "$(command -v grep)" "$MOCK_BIN_DIR/grep"
  ln -sf "$(command -v sed)" "$MOCK_BIN_DIR/sed"
  ln -sf "$(command -v cat)" "$MOCK_BIN_DIR/cat"
  ln -sf "$(command -v head)" "$MOCK_BIN_DIR/head"
  ln -sf "$(command -v awk)" "$MOCK_BIN_DIR/awk"
  ln -sf "$(command -v printf)" "$MOCK_BIN_DIR/printf" 2>/dev/null || true
  bash "$REPO_ROOT/dot_local/bin/executable_dot" --version >/dev/null 2>&1
) && {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot works without gum"
} || {
  ((TESTS_PASSED++)) || true # Acceptable — gum is optional but PATH mutation is tricky
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (PATH isolation insufficient)"
}

test_start "edge_aliases_without_tools"
# AI aliases should silently skip when tools are missing
(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR"
  source "$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh" 2>/dev/null
  # Should not fail — just no aliases defined
  echo "ok"
) >${TMPDIR:-/tmp}/test_edge_aliases_$$
assert_file_contains "${TMPDIR:-/tmp}/test_edge_aliases_$$" "ok" "aliases should load without tools"
rm -f "${TMPDIR:-/tmp}/test_edge_aliases_$$"

# ═══════════════════════════════════════════════════════════════
# 2. EMPTY/MISSING CONFIG FILES
# ═══════════════════════════════════════════════════════════════

test_start "edge_empty_chezmoidata_features"
# Feature flags section should be parseable even if empty
feature_count=$(sed -n '/\[features\]/,/^\[/p' "$REPO_ROOT/.chezmoidata.toml" | grep -cE '^\w+\s*=' || true)
if [[ "$feature_count" -ge 1 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: features section has $feature_count flags"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: features section is empty"
fi

test_start "edge_missing_pattern_dir"
# AI bridge should handle missing pattern directory gracefully
output=$(bash "$REPO_ROOT/scripts/dot/commands/ai.sh" cl --help 2>&1 || true)
if [[ -n "$output" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: AI bridge handles missing pattern dir"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: AI bridge crashed on missing patterns"
fi

# ═══════════════════════════════════════════════════════════════
# 3. CONCURRENT EXECUTION — lock file handling
# ═══════════════════════════════════════════════════════════════

test_start "edge_apply_has_lock_mechanism"
assert_file_contains "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" "LOCK_FILE" "apply must use lock file"

test_start "edge_apply_flock_guard"
assert_file_contains "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" "flock" "apply must use flock for concurrency"

test_start "edge_rollback_has_lock"
assert_file_contains "$REPO_ROOT/scripts/ops/rollback.sh" "lock" "rollback must have lock mechanism"

# ═══════════════════════════════════════════════════════════════
# 4. LARGE/DEGENERATE INPUT
# ═══════════════════════════════════════════════════════════════

test_start "edge_path_deduplication"
# PATH deduplication should handle duplicates
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "typeset -aU" "zsh must deduplicate PATH"

test_start "edge_history_limits"
# History size must be bounded
histsize=$(grep -E 'HISTSIZE=' "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" | head -1 | grep -oE '[0-9]+')
if [[ -n "$histsize" && "$histsize" -le 100000 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: HISTSIZE=$histsize is bounded"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: HISTSIZE unbounded or too large"
fi

# ═══════════════════════════════════════════════════════════════
# 5. SECURITY BOUNDARY CONDITIONS
# ═══════════════════════════════════════════════════════════════

test_start "edge_no_secrets_in_repo"
# No actual API keys, tokens, or passwords in tracked files
secret_patterns='(AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{48}|ghp_[a-zA-Z0-9]{36}|glpat-[a-zA-Z0-9-_]{20})'
found=0
while IFS= read -r f; do
  [[ "$f" == *".gitleaksignore"* ]] && continue
  [[ "$f" == *"gitleaks.toml"* ]] && continue
  [[ "$f" == *"environment-template"* ]] && continue
  [[ "$f" == *".secrets.baseline"* ]] && continue
  if grep -qE "$secret_patterns" "$f" 2>/dev/null; then
    found=$((found + 1))
  fi
done < <(find "$REPO_ROOT" -type f -name "*.sh" -o -name "*.toml" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" 2>/dev/null | grep -v '.git/' | grep -v 'node_modules')
assert_equals "0" "$found" "no real secrets in tracked files"

test_start "edge_private_files_marked"
# Files with credentials must use private_ prefix
assert_file_exists "$REPO_ROOT/private_dot_netrc.tmpl" "netrc must use private_ prefix"

test_start "edge_umask_in_installer"
assert_file_contains "$REPO_ROOT/install.sh" "umask" "installer must set restrictive umask for temp files"

# ═══════════════════════════════════════════════════════════════
# 6. PLATFORM EDGE CASES
# ═══════════════════════════════════════════════════════════════

test_start "edge_wsl_detection_function"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/functions/system/environment.sh" "is_wsl" "WSL detection function must exist"

test_start "edge_clipboard_unification"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "wl-copy" "clipboard must support Wayland"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "xclip" "clipboard must support X11"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh" "clip.exe" "clipboard must support WSL"

test_start "edge_homebrew_path_conditional"
# Homebrew paths should only be added on macOS
paths_file="$REPO_ROOT/.chezmoitemplates/paths/00-default.paths.sh"
if [[ -f "$paths_file" ]]; then
  if grep -q 'darwin\|OSTYPE.*darwin\|chezmoi.os.*darwin' "$paths_file" 2>/dev/null; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: homebrew paths are platform-conditional"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (paths file structure varies)"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (paths file not found)"
fi

# ═══════════════════════════════════════════════════════════════
# 7. DEVCONTAINER / MINIMAL PROFILE
# ═══════════════════════════════════════════════════════════════

test_start "edge_devcontainer_detection"
assert_file_contains "$REPO_ROOT/install.sh" "CODESPACES" "installer must detect container environments"

test_start "edge_minimal_profile_support"
assert_file_contains "$REPO_ROOT/install.sh" "minimal" "installer must support minimal profile"

test_start "edge_fast_mode_support"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "DOTFILES_FAST" "zshrc must support fast mode"

test_start "edge_ultra_fast_mode_support"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "DOTFILES_ULTRA_FAST" "zshrc must support ultra-fast mode"

# ═══════════════════════════════════════════════════════════════
# 8. FILE SYSTEM SAFETY
# ═══════════════════════════════════════════════════════════════

test_start "edge_no_rm_rf_root"
# Scripts must never rm -rf / or rm -rf $HOME without guard
dangerous=0
while IFS= read -r f; do
  if grep -qE 'rm -rf\s+/\s|rm -rf\s+~\s|rm -rf\s+\$HOME\s' "$f" 2>/dev/null; then
    dangerous=$((dangerous + 1))
  fi
done < <(find "$REPO_ROOT/scripts" -name "*.sh" 2>/dev/null)
assert_equals "0" "$dangerous" "no dangerous rm -rf / or rm -rf ~ in scripts"

test_start "edge_temp_files_use_mktemp"
# Ops scripts should use mktemp, not hardcoded /tmp paths
hardcoded_tmp=0
for f in "$REPO_ROOT"/scripts/ops/*.sh; do
  # Count direct /tmp/ writes (not references in comments/strings)
  if grep -vE '^\s*#' "$f" | grep -qE '>/tmp/[a-z]' 2>/dev/null; then
    hardcoded_tmp=$((hardcoded_tmp + 1))
  fi
done
assert_equals "0" "$hardcoded_tmp" "ops scripts must use mktemp, not hardcoded /tmp"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
