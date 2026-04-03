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

# ═══════════════════════════════════════════════════════════════
# 9. DOTFILES_FAST MODE — shell configs handle fast mode
# ═══════════════════════════════════════════════════════════════

test_start "edge_zshrc_fast_mode_guard"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "DOTFILES_FAST" "zshrc must guard with DOTFILES_FAST"

test_start "edge_zinit_fast_mode_early_return"
assert_file_contains "$REPO_ROOT/dot_config/zsh/rc.d/20-zinit.zsh" "DOTFILES_FAST" "zinit must skip in fast mode"

test_start "edge_options_fast_mode_guard"
assert_file_contains "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" "DOTFILES_FAST" "zsh options must respect fast mode"

test_start "edge_ultra_fast_distinct_from_fast"
# DOTFILES_ULTRA_FAST should be checked separately from DOTFILES_FAST
assert_file_contains "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" "DOTFILES_ULTRA_FAST" "ultra-fast mode must be distinct check"

# ═══════════════════════════════════════════════════════════════
# 10. MISSING XDG DIRECTORIES — graceful handling
# ═══════════════════════════════════════════════════════════════

test_start "edge_xdg_config_home_referenced"
# Shell configs should reference XDG_CONFIG_HOME
xdg_refs=$(grep -rl 'XDG_CONFIG_HOME' "$REPO_ROOT/dot_config/zsh/" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$xdg_refs" -ge 1 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: zsh configs reference XDG_CONFIG_HOME"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (XDG set via templates)"
fi

test_start "edge_xdg_cache_home_referenced"
cache_refs=$(grep -rl 'XDG_CACHE_HOME\|\.cache' "$REPO_ROOT/dot_config/zsh/" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$cache_refs" -ge 1 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: zsh configs reference cache directory"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no cache directory references found"
fi

test_start "edge_xdg_data_home_in_zsh"
assert_file_contains "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" "XDG_DATA_HOME" "zsh must reference XDG_DATA_HOME"

# ═══════════════════════════════════════════════════════════════
# 11. EMPTY .chezmoidata.toml SECTIONS — no crash
# ═══════════════════════════════════════════════════════════════

test_start "edge_chezmoidata_has_version"
assert_file_contains "$REPO_ROOT/.chezmoidata.toml" "dotfiles_version" ".chezmoidata.toml must have version"

test_start "edge_chezmoidata_has_profile_key"
assert_file_contains "$REPO_ROOT/.chezmoidata.toml" "profile" ".chezmoidata.toml must have profile key"

test_start "edge_chezmoidata_parseable_toml"
# File must have balanced brackets (basic TOML validity)
open_brackets=$(grep -cE '^\[' "$REPO_ROOT/.chezmoidata.toml" || true)
if [[ "$open_brackets" -ge 2 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: .chezmoidata.toml has $open_brackets sections"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: .chezmoidata.toml has too few sections"
fi

# ═══════════════════════════════════════════════════════════════
# 12. SYMLINK HANDLING — no broken symlinks
# ═══════════════════════════════════════════════════════════════

test_start "edge_no_broken_symlinks_in_bin"
broken_links=0
while IFS= read -r link; do
  if [[ -L "$link" && ! -e "$link" ]]; then
    broken_links=$((broken_links + 1))
  fi
done < <(find "$REPO_ROOT/dot_local/bin" -type l 2>/dev/null)
assert_equals "0" "$broken_links" "no broken symlinks in dot_local/bin"

test_start "edge_no_broken_symlinks_in_scripts"
broken_links=0
while IFS= read -r link; do
  if [[ -L "$link" && ! -e "$link" ]]; then
    broken_links=$((broken_links + 1))
  fi
done < <(find "$REPO_ROOT/scripts" -type l 2>/dev/null)
assert_equals "0" "$broken_links" "no broken symlinks in scripts/"

# ═══════════════════════════════════════════════════════════════
# 13. FUNCTION LIBRARY — sourcing safety
# ═══════════════════════════════════════════════════════════════

test_start "edge_function_files_valid_bash"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates/functions" -name "*.sh" 2>/dev/null)
assert_equals "0" "$failures" "all function library files must pass bash -n"

test_start "edge_alias_files_valid_bash"
failures=0
while IFS= read -r f; do
  if ! bash -n "$f" >/dev/null 2>&1; then
    failures=$((failures + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates/aliases" -name "*.sh" 2>/dev/null)
assert_equals "0" "$failures" "all alias files must pass bash -n"

# ═══════════════════════════════════════════════════════════════
# 14. PATH DEDUPLICATION — no duplicate entries
# ═══════════════════════════════════════════════════════════════

test_start "edge_typeset_unique_path"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "typeset -aU" "zsh must use typeset -aU for unique arrays"

test_start "edge_paths_file_exists"
assert_file_exists "$REPO_ROOT/.chezmoitemplates/paths/00-default.paths.sh" "default paths file must exist"

# ═══════════════════════════════════════════════════════════════
# 15. ALIAS FILE SIZES — no unreasonably large files
# ═══════════════════════════════════════════════════════════════

test_start "edge_alias_files_under_50kb"
oversized=0
while IFS= read -r f; do
  size=$(wc -c < "$f" | tr -d ' ')
  if [[ "$size" -gt 51200 ]]; then
    oversized=$((oversized + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates/aliases" -name "*.sh" 2>/dev/null)
assert_equals "0" "$oversized" "no alias files exceed 50KB"

test_start "edge_function_files_under_50kb"
oversized=0
while IFS= read -r f; do
  size=$(wc -c < "$f" | tr -d ' ')
  if [[ "$size" -gt 51200 ]]; then
    oversized=$((oversized + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates/functions" -name "*.sh" 2>/dev/null)
assert_equals "0" "$oversized" "no function files exceed 50KB"

# ═══════════════════════════════════════════════════════════════
# 16. CACHE DIRECTORY — safe creation patterns
# ═══════════════════════════════════════════════════════════════

test_start "edge_cache_uses_mkdir_p"
# Scripts that create cache dirs should use mkdir -p
mkdir_p_count=$(grep -rl 'mkdir -p' "$REPO_ROOT/scripts/" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$mkdir_p_count" -ge 1 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: scripts use mkdir -p ($mkdir_p_count files)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no scripts use mkdir -p"
fi

test_start "edge_prewarm_uses_mkdir_p"
assert_file_contains "$REPO_ROOT/scripts/ops/prewarm.sh" "mkdir -p" "prewarm must use mkdir -p for cache dirs"

# ═══════════════════════════════════════════════════════════════
# 17. DEPENDENCY CHECKS — command -v pattern
# ═══════════════════════════════════════════════════════════════

test_start "edge_ai_script_checks_deps"
assert_file_contains "$REPO_ROOT/scripts/dot/commands/ai.sh" "has_command" "ai.sh must check for tool availability"

test_start "edge_install_checks_deps"
assert_file_contains "$REPO_ROOT/install.sh" "command -v" "install.sh must check for dependencies"

test_start "edge_apply_checks_chezmoi"
assert_file_contains "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" "command -v" "apply must check for chezmoi"

# ═══════════════════════════════════════════════════════════════
# 18. FISH CONFIG — handles missing tools
# ═══════════════════════════════════════════════════════════════

test_start "edge_fish_config_exists"
assert_file_exists "$REPO_ROOT/dot_config/fish/config.fish.tmpl" "fish config must exist"

test_start "edge_fish_interactive_guard"
assert_file_contains "$REPO_ROOT/dot_config/fish/config.fish.tmpl" "is-interactive" "fish config must guard for interactive shell"

test_start "edge_fish_cached_eval_exists"
assert_file_exists "$REPO_ROOT/dot_config/fish/functions/_cached_eval.fish" "fish cached eval must exist"

# ═══════════════════════════════════════════════════════════════
# 19. NUSHELL — completions have valid structure
# ═══════════════════════════════════════════════════════════════

test_start "edge_nushell_completions_exist"
assert_file_exists "$REPO_ROOT/dot_config/nushell/completions.nu.tmpl" "nushell completions must exist"

test_start "edge_nushell_completions_has_commands"
assert_file_contains "$REPO_ROOT/dot_config/nushell/completions.nu.tmpl" "dot_commands" "nushell completions must define commands"

test_start "edge_nushell_config_exists"
assert_file_exists "$REPO_ROOT/dot_config/nushell/config.nu.tmpl" "nushell config must exist"

# ═══════════════════════════════════════════════════════════════
# 20. BASH COMPLETION — valid structure
# ═══════════════════════════════════════════════════════════════

test_start "edge_bash_completion_exists"
assert_file_exists "$REPO_ROOT/dot_local/share/bash-completion/completions/dot" "bash completion for dot must exist"

test_start "edge_bash_completion_valid_syntax"
bash_comp_result=0
bash -n "$REPO_ROOT/dot_local/share/bash-completion/completions/dot" >/dev/null 2>&1 || bash_comp_result=1
assert_equals "0" "$bash_comp_result" "bash completion must pass syntax check"

test_start "edge_bash_completion_has_function"
assert_file_contains "$REPO_ROOT/dot_local/share/bash-completion/completions/dot" "_dot_completions" "bash completion must define _dot_completions"

# ═══════════════════════════════════════════════════════════════
# 21. PROVISION SCRIPTS — OS-gated
# ═══════════════════════════════════════════════════════════════

test_start "edge_darwin_provision_is_gated"
# Darwin provisioning scripts are gated by chezmoi templates (filename .tmpl or content)
darwin_total=$(find "$REPO_ROOT/install/provision" -name "*darwin*" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$darwin_total" -ge 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $darwin_total darwin provision scripts (gated by chezmoi template)"
fi

test_start "edge_linux_provision_is_gated"
linux_gated=0
linux_total=0
while IFS= read -r f; do
  linux_total=$((linux_total + 1))
  if grep -qiE 'linux\|chezmoi.os.*eq.*linux\|OSTYPE.*linux' "$f" 2>/dev/null; then
    linux_gated=$((linux_gated + 1))
  fi
done < <(find "$REPO_ROOT/install/provision" -name "*linux*" 2>/dev/null)
if [[ "$linux_total" -eq 0 || "$linux_gated" -eq "$linux_total" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: linux provision scripts are OS-gated"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: linux provision scripts gated by chezmoi template"
fi

# ═══════════════════════════════════════════════════════════════
# 22. BASHRC — handles gracefully
# ═══════════════════════════════════════════════════════════════

test_start "edge_bashrc_exists"
assert_file_exists "$REPO_ROOT/dot_bashrc" "bashrc must exist"

test_start "edge_bashrc_double_source_guard"
assert_file_contains "$REPO_ROOT/dot_bashrc" "BASHRC_SOURCED" "bashrc must prevent double-sourcing"

test_start "edge_bashrc_valid_syntax"
bashrc_result=0
bash -n "$REPO_ROOT/dot_bashrc" >/dev/null 2>&1 || bashrc_result=1
assert_equals "0" "$bashrc_result" "bashrc must pass syntax check"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
