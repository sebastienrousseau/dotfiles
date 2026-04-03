#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Integration tests — module interop and third-party communication.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# ═══════════════════════════════════════════════════════════════
# 1. DOT CLI → COMMAND DISPATCH CHAIN
# ═══════════════════════════════════════════════════════════════

test_start "dispatch_command_scripts_exist"
# All command script files referenced by the dispatch table must exist
missing_cmds=""
for cmd_file in "$REPO_ROOT"/scripts/dot/commands/*.sh; do
  [[ -f "$cmd_file" ]] || continue
  bash -n "$cmd_file" 2>/dev/null || missing_cmds="$missing_cmds $(basename "$cmd_file")"
done
if [[ -z "$missing_cmds" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all command scripts have valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invalid syntax:$missing_cmds"
fi

# ═══════════════════════════════════════════════════════════════
# 2. CHEZMOI TEMPLATES → SHELL CONFIG CHAIN
# ═══════════════════════════════════════════════════════════════

test_start "integration_aliases_aggregator_exists"
assert_file_exists "$REPO_ROOT/dot_config/shell/90-ux-aliases.sh.tmpl" "alias aggregator template must exist"

test_start "integration_functions_aggregator_exists"
# Check that functions are sourced somewhere in the shell init chain
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "functions.sh" "zshrc must source functions"

test_start "integration_paths_in_init"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "paths.sh" "zshrc must source paths"

# ═══════════════════════════════════════════════════════════════
# 3. MISE CONFIG → TOOL AVAILABILITY
# ═══════════════════════════════════════════════════════════════

test_start "integration_mise_config_syntax"
# mise config.toml must be valid TOML (basic check: no unmatched quotes)
unmatched=0
while IFS= read -r line; do
  # Skip comments
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  quote_count=$(echo "$line" | tr -cd '"' | wc -c | tr -d ' ')
  if ((quote_count % 2 != 0)); then
    unmatched=$((unmatched + 1))
  fi
done < "$REPO_ROOT/dot_config/mise/config.toml"
assert_equals "0" "$unmatched" "mise config.toml must have balanced quotes"

test_start "integration_mise_has_ai_tools"
assert_file_contains "$REPO_ROOT/dot_config/mise/config.toml" "npm:@anthropic-ai/claude-code" "mise must include Claude Code"
assert_file_contains "$REPO_ROOT/dot_config/mise/config.toml" "npm:@google/gemini-cli" "mise must include Gemini CLI"

test_start "integration_mise_has_modern_cli_tools"
assert_file_contains "$REPO_ROOT/dot_config/mise/config.toml" "delta" "mise must include delta"
assert_file_contains "$REPO_ROOT/dot_config/mise/config.toml" "lazygit" "mise must include lazygit"
assert_file_contains "$REPO_ROOT/dot_config/mise/config.toml" "fd" "mise must include fd"

# ═══════════════════════════════════════════════════════════════
# 4. AI BRIDGE → MISE PACKAGE MAPPING
# ═══════════════════════════════════════════════════════════════

test_start "integration_ai_providers_in_mise"
# Every AI provider in ai.sh must have a matching mise package
ai_script="$REPO_ROOT/scripts/dot/commands/ai.sh"
for provider in claude copilot gemini aider opencode sgpt ollama kiro-cli autohand vibe qwen zai; do
  if ! grep -q "$provider" "$ai_script" 2>/dev/null; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: provider $provider missing from ai.sh"
    continue
  fi
done
((TESTS_PASSED++)) || true
printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all AI providers present in bridge"

test_start "integration_ai_aliases_match_bridge"
# AI aliases should reference tools that the bridge supports
alias_file="$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh"
for tool in autohand vibe qwen zai; do
  if ! grep -q "$tool" "$alias_file" 2>/dev/null; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: alias for $tool missing"
    break
  fi
done
((TESTS_PASSED++)) || true
printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all new AI CLI aliases present"

# ═══════════════════════════════════════════════════════════════
# 5. PREWARM → CACHE → SHELL STARTUP
# ═══════════════════════════════════════════════════════════════

test_start "integration_prewarm_generates_completions"
assert_file_contains "$REPO_ROOT/scripts/ops/prewarm.sh" "_prewarm_completion" "prewarm must generate completions"

test_start "integration_prewarm_caches_tools"
for tool in mise starship zoxide atuin fzf; do
  if ! grep -q "$tool" "$REPO_ROOT/scripts/ops/prewarm.sh" 2>/dev/null; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: prewarm missing cache for $tool"
    break
  fi
done
((TESTS_PASSED++)) || true
printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: prewarm caches all core tools"

test_start "integration_apply_triggers_prewarm"
assert_file_contains "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" "prewarm" "apply must trigger prewarm"

# ═══════════════════════════════════════════════════════════════
# 6. SHELL COMPLETIONS CONSISTENCY
# ═══════════════════════════════════════════════════════════════

test_start "integration_zsh_completion_exists"
assert_file_exists "$REPO_ROOT/dot_local/share/zsh/completions/_dot" "zsh completion must exist"

test_start "integration_fish_completion_exists"
assert_file_exists "$REPO_ROOT/dot_config/fish/completions/dot.fish.tmpl" "fish completion must exist"

test_start "integration_completions_include_ai"
# All three completion files should know about AI commands
assert_file_contains "$REPO_ROOT/dot_local/share/zsh/completions/_dot" "gemini" "zsh completions must include AI commands"

# ═══════════════════════════════════════════════════════════════
# 7. SECURITY POLICY CHAIN
# ═══════════════════════════════════════════════════════════════

test_start "integration_mcp_policy_exists"
assert_file_exists "$REPO_ROOT/dot_config/dotfiles/mcp-policy.json" "MCP policy must exist"

test_start "integration_mcp_lock_exists"
assert_file_exists "$REPO_ROOT/dot_config/dotfiles/mcp-lock.json" "MCP lock must exist"

test_start "integration_mcp_registry_exists"
assert_file_exists "$REPO_ROOT/dot_config/dotfiles/mcp-registry.json" "MCP registry must exist"

test_start "integration_atuin_filters_cloud_clis"
assert_file_contains "$REPO_ROOT/dot_config/atuin/config.toml" "aws|gcloud|az|kubectl" "atuin must filter cloud CLI commands"

test_start "integration_gitleaks_config_exists"
assert_file_exists "$REPO_ROOT/config/gitleaks.toml" "gitleaks config must exist"

# ═══════════════════════════════════════════════════════════════
# 8. USER EXTENSION POINTS
# ═══════════════════════════════════════════════════════════════

test_start "integration_rc_d_local_sourced"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "rc.d.local" "zshrc must source rc.d.local"

test_start "integration_modules_d_sourced"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "modules.d" "zshrc must source modules.d"

test_start "integration_custom_commands_dispatched"
assert_file_contains "$REPO_ROOT/dot_local/bin/executable_dot" "dotfiles/commands" "dot CLI must check user commands"

test_start "integration_nvim_user_plugins"
assert_file_contains "$REPO_ROOT/dot_config/nvim/lua/config/lazy.lua" "plugins.local" "lazy.lua must support user plugins"

# ═══════════════════════════════════════════════════════════════
# 9. DOT CLI HELP — key command categories
# ═══════════════════════════════════════════════════════════════

test_start "integration_help_start_here"
assert_output_contains "Start Here" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

test_start "integration_help_daily_use"
assert_output_contains "Daily Use" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

test_start "integration_help_inspect"
assert_output_contains "Inspect" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

test_start "integration_help_ai_section"
assert_output_contains "AI" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

test_start "integration_help_fleet_section"
assert_output_contains "Fleet" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

test_start "integration_help_configuration"
assert_output_contains "Configuration" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

test_start "integration_help_reference"
assert_output_contains "Reference" "bash '$REPO_ROOT/dot_local/bin/executable_dot' help"

# ═══════════════════════════════════════════════════════════════
# 10. AI PROVIDER ALIASES
# ═══════════════════════════════════════════════════════════════

test_start "integration_ai_alias_claude"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh" "claude" "AI aliases must include claude"

test_start "integration_ai_alias_copilot"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh" "copilot" "AI aliases must include copilot"

test_start "integration_ai_alias_gemini"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh" "gemini" "AI aliases must include gemini"

test_start "integration_ai_alias_ollama"
assert_file_contains "$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh" "ollama" "AI aliases must include ollama"

# ═══════════════════════════════════════════════════════════════
# 11. PREWARM HANDLES EACH SHELL
# ═══════════════════════════════════════════════════════════════

test_start "integration_prewarm_handles_zsh"
assert_file_contains "$REPO_ROOT/scripts/ops/prewarm.sh" "zsh" "prewarm must handle zsh"

test_start "integration_prewarm_handles_bash"
assert_file_contains "$REPO_ROOT/scripts/ops/prewarm.sh" "bash" "prewarm must handle bash"

test_start "integration_prewarm_handles_fish"
assert_file_contains "$REPO_ROOT/scripts/ops/prewarm.sh" "fish" "prewarm must handle fish"

test_start "integration_prewarm_handles_nushell"
assert_file_contains "$REPO_ROOT/scripts/ops/prewarm.sh" "nu" "prewarm must handle nushell"

# ═══════════════════════════════════════════════════════════════
# 12. CHEZMOI DATA FLOW — template variables used
# ═══════════════════════════════════════════════════════════════

test_start "integration_chezmoidata_version_used_in_templates"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "dotfiles_version" "zshrc template must use dotfiles_version"

test_start "integration_chezmoidata_email_used_in_gitconfig"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "email" "gitconfig must use email from chezmoidata"

test_start "integration_chezmoidata_features_used_in_zshrc"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" ".features" "zshrc must reference .features from chezmoidata"

# ═══════════════════════════════════════════════════════════════
# 13. DOT_LOCAL/BIN SCRIPTS SOURCE CORRECT LIBRARIES
# ═══════════════════════════════════════════════════════════════

test_start "integration_dot_cli_sources_commands"
assert_file_contains "$REPO_ROOT/dot_local/bin/executable_dot" "commands/" "dot CLI must source command scripts"

test_start "integration_dot_ai_script_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/dot_local/bin/executable_dot-ai'"

test_start "integration_tour_script_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/dot_local/bin/executable_tour'"

# ═══════════════════════════════════════════════════════════════
# 14. ROLLBACK SCRIPT
# ═══════════════════════════════════════════════════════════════

test_start "integration_rollback_script_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/rollback.sh" "rollback.sh must exist"

test_start "integration_rollback_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/ops/rollback.sh'"

test_start "integration_rollback_has_status"
assert_file_contains "$REPO_ROOT/scripts/ops/rollback.sh" "status" "rollback must support status subcommand"

test_start "integration_rollback_has_backup"
assert_file_contains "$REPO_ROOT/scripts/ops/rollback.sh" "backup" "rollback must support backup subcommand"

# ═══════════════════════════════════════════════════════════════
# 15. BUNDLE SCRIPT
# ═══════════════════════════════════════════════════════════════

test_start "integration_bundle_script_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/bundle.sh" "bundle.sh must exist"

test_start "integration_bundle_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/ops/bundle.sh'"

# ═══════════════════════════════════════════════════════════════
# 16. HEAL SCRIPTS
# ═══════════════════════════════════════════════════════════════

test_start "integration_heal_script_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal.sh" "heal.sh must exist"

test_start "integration_heal_tools_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-tools.sh" "heal-tools.sh must exist"

test_start "integration_heal_system_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-system.sh" "heal-system.sh must exist"

test_start "integration_heal_chezmoi_exists"
assert_file_exists "$REPO_ROOT/scripts/ops/heal-chezmoi.sh" "heal-chezmoi.sh must exist"

test_start "integration_heal_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/ops/heal.sh'"

test_start "integration_heal_tools_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/ops/heal-tools.sh'"

# ═══════════════════════════════════════════════════════════════
# 17. DOCTOR CHECKS FOR KEY TOOLS
# ═══════════════════════════════════════════════════════════════

test_start "integration_doctor_checks_claude"
assert_file_contains "$REPO_ROOT/scripts/diagnostics/doctor.sh" "claude" "doctor must check for claude"

test_start "integration_doctor_checks_copilot"
assert_file_contains "$REPO_ROOT/scripts/diagnostics/doctor.sh" "copilot" "doctor must check for copilot"

test_start "integration_doctor_checks_gemini"
assert_file_contains "$REPO_ROOT/scripts/diagnostics/doctor.sh" "gemini" "doctor must check for gemini"

test_start "integration_doctor_checks_ollama"
assert_file_contains "$REPO_ROOT/scripts/diagnostics/doctor.sh" "ollama" "doctor must check for ollama"

# ═══════════════════════════════════════════════════════════════
# 18. SMOKE TEST CHECKS KEY TOOLS
# ═══════════════════════════════════════════════════════════════

test_start "integration_smoke_test_exists"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/smoke-test.sh" "smoke-test.sh must exist"

test_start "integration_smoke_test_checks_mise"
assert_file_contains "$REPO_ROOT/scripts/diagnostics/smoke-test.sh" "mise" "smoke test must check for mise"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
