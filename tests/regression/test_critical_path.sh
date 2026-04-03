#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Critical path tests — must-work features that gate every release.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
CHEZMOIDATA="$REPO_ROOT/.chezmoidata.toml"

# ═══════════════════════════════════════════════════════════════
# 1. CHEZMOI APPLY (the most critical operation)
# ═══════════════════════════════════════════════════════════════

test_start "critical_chezmoi_apply_script_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/ops/chezmoi-apply.sh'"

test_start "critical_chezmoidata_exists"
assert_file_exists "$CHEZMOIDATA" ".chezmoidata.toml must exist"

test_start "critical_chezmoidata_has_version"
assert_file_contains "$CHEZMOIDATA" "dotfiles_version" "must define dotfiles_version"

test_start "critical_chezmoidata_has_features"
assert_file_contains "$CHEZMOIDATA" "[features]" "must define features section"

test_start "critical_chezmoidata_has_profile"
assert_file_contains "$CHEZMOIDATA" "profile" "must define profile"

# ═══════════════════════════════════════════════════════════════
# 2. DOT CLI (the control plane)
# ═══════════════════════════════════════════════════════════════

test_start "critical_dot_cli_exists"
assert_file_exists "$DOT_CLI" "dot CLI must exist"

test_start "critical_dot_cli_syntax"
assert_exit_code 0 "bash -n '$DOT_CLI'"

test_start "critical_dot_version"
assert_output_contains "dotfiles" "bash '$DOT_CLI' --version"

test_start "critical_dot_help_runs"
assert_exit_code 0 "bash '$DOT_CLI' help"

test_start "critical_dot_unknown_cmd_fails"
assert_exit_code 1 "bash '$DOT_CLI' __nonexistent_command_xyzzy__"

test_start "critical_dot_help_lists_sync"
assert_output_contains "sync" "bash '$DOT_CLI' help"

test_start "critical_dot_help_lists_doctor"
assert_output_contains "doctor" "bash '$DOT_CLI' help"

test_start "critical_dot_help_lists_ai"
assert_output_contains "AI" "bash '$DOT_CLI' help"

# ═══════════════════════════════════════════════════════════════
# 3. SHELL STARTUP CHAIN (must not break interactive shells)
# ═══════════════════════════════════════════════════════════════

test_start "critical_zshrc_template_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "zshrc template must exist"

test_start "critical_zshenv_exists"
assert_file_exists "$REPO_ROOT/dot_zshenv" "zshenv must exist"

test_start "critical_bashrc_exists"
assert_file_exists "$REPO_ROOT/dot_bashrc" "bashrc must exist"

test_start "critical_bashrc_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/dot_bashrc'"

test_start "critical_rc_d_ordering"
# rc.d files must follow numeric prefix ordering
rc_files=$(ls "$REPO_ROOT/dot_config/zsh/rc.d/" 2>/dev/null | sort)
prev_prefix="-1"
ordering_ok=true
while IFS= read -r f; do
  prefix="${f%%[-_]*}"
  prefix="${prefix//[!0-9]/}"
  if [[ -n "$prefix" && "$prefix" -lt "$prev_prefix" ]]; then
    ordering_ok=false
  fi
  [[ -n "$prefix" ]] && prev_prefix="$prefix"
done <<<"$rc_files"
if $ordering_ok; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rc.d files follow numeric ordering"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc.d files must follow numeric ordering"
fi

test_start "critical_aliases_file_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh'"

test_start "critical_default_aliases_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/default/default.aliases.sh'"

# ═══════════════════════════════════════════════════════════════
# 4. DIAGNOSTICS (must always be able to report health)
# ═══════════════════════════════════════════════════════════════

test_start "critical_doctor_script_exists"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/doctor.sh" "doctor.sh must exist"

test_start "critical_doctor_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/diagnostics/doctor.sh'"

test_start "critical_health_script_exists"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/health.sh" "health.sh must exist"

test_start "critical_smoke_test_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/diagnostics/smoke-test.sh'"

# ═══════════════════════════════════════════════════════════════
# 5. AI CLI STATUS (must always report, even with no tools)
# ═══════════════════════════════════════════════════════════════

test_start "critical_ai_command_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/ai.sh'"

test_start "critical_ai_mise_pkg_mapping"
assert_file_contains "$REPO_ROOT/scripts/dot/commands/ai.sh" "_ai_mise_pkg" "must define mise package mapping"

test_start "critical_ai_bridge_help"
output=$(bash "$REPO_ROOT/scripts/dot/commands/ai.sh" cl --help 2>&1 || true)
if echo "$output" | grep -q "Available Patterns"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: AI bridge help shows available patterns"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: AI bridge help should show patterns"
fi

# ═══════════════════════════════════════════════════════════════
# 6. INSTALLER (must be safe to run)
# ═══════════════════════════════════════════════════════════════

test_start "critical_installer_exists"
assert_file_exists "$REPO_ROOT/install.sh" "install.sh must exist"

test_start "critical_installer_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/install.sh'"

test_start "critical_installer_help"
assert_output_contains "Usage" "bash '$REPO_ROOT/install.sh' --help"

test_start "critical_uninstaller_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/uninstall.sh'"

# ═══════════════════════════════════════════════════════════════
# 7. PREWARM (must be able to regenerate caches)
# ═══════════════════════════════════════════════════════════════

test_start "critical_prewarm_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/ops/prewarm.sh'"

test_start "critical_prewarm_in_apply"
assert_file_contains "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" "DOTFILES_PREWARM_ON_APPLY" "apply must support prewarm"

# ═══════════════════════════════════════════════════════════════
# 8. RC.D FILES — each must have valid bash/zsh syntax
# ═══════════════════════════════════════════════════════════════

test_start "critical_rc_d_00_alias_shims_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/00-alias-shims.zsh" "00-alias-shims.zsh must exist"

test_start "critical_rc_d_05_ssh_agent_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/05-ssh-agent.zsh" "05-ssh-agent.zsh must exist"

test_start "critical_rc_d_10_env_template_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/10-env.zsh.tmpl" "10-env.zsh.tmpl must exist"

test_start "critical_rc_d_20_zinit_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/20-zinit.zsh" "20-zinit.zsh must exist"

test_start "critical_rc_d_30_options_template_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" "30-options.zsh.tmpl must exist"

test_start "critical_rc_d_40_bell_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/40-bell.zsh" "40-bell.zsh must exist"

test_start "critical_rc_d_50_fortune_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/50-login-fortune.zsh" "50-login-fortune.zsh must exist"

test_start "critical_rc_d_99_alias_wrapper_exists"
assert_file_exists "$REPO_ROOT/dot_config/zsh/rc.d/99-alias-wrapper.zsh" "99-alias-wrapper.zsh must exist"

# ═══════════════════════════════════════════════════════════════
# 9. DOT COMMAND SCRIPTS — all must exist and have valid syntax
# ═══════════════════════════════════════════════════════════════

test_start "critical_dot_cmd_core_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/core.sh'"

test_start "critical_dot_cmd_diagnostics_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/diagnostics.sh'"

test_start "critical_dot_cmd_aliases_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/aliases.sh'"

test_start "critical_dot_cmd_tools_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/tools.sh'"

test_start "critical_dot_cmd_meta_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/meta.sh'"

test_start "critical_dot_cmd_secrets_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/secrets.sh'"

test_start "critical_dot_cmd_security_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/security.sh'"

test_start "critical_dot_cmd_agent_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/agent.sh'"

test_start "critical_dot_cmd_appearance_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/appearance.sh'"

test_start "critical_dot_cmd_fleet_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/fleet.sh'"

test_start "critical_dot_cmd_lint_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/lint.sh'"

test_start "critical_dot_cmd_patterns_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/patterns.sh'"

test_start "critical_dot_cmd_restore_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/scripts/dot/commands/restore.sh'"

# ═══════════════════════════════════════════════════════════════
# 10. KEY DOT_LOCAL/BIN EXECUTABLES
# ═══════════════════════════════════════════════════════════════

test_start "critical_bin_dot_exists"
assert_file_exists "$REPO_ROOT/dot_local/bin/executable_dot" "dot executable must exist"

test_start "critical_bin_tour_exists"
assert_file_exists "$REPO_ROOT/dot_local/bin/executable_tour" "tour executable must exist"

test_start "critical_bin_dot_ai_exists"
assert_file_exists "$REPO_ROOT/dot_local/bin/executable_dot-ai" "dot-ai executable must exist"

test_start "critical_bin_extract_exists"
assert_file_exists "$REPO_ROOT/dot_local/bin/executable_extract" "extract executable must exist"

test_start "critical_bin_uuid_exists"
assert_file_exists "$REPO_ROOT/dot_local/bin/executable_uuid" "uuid executable must exist"

# ═══════════════════════════════════════════════════════════════
# 11. CHEZMOI TEMPLATE FILES EXIST
# ═══════════════════════════════════════════════════════════════

test_start "critical_gitconfig_template_exists"
assert_file_exists "$REPO_ROOT/dot_gitconfig.tmpl" "dot_gitconfig.tmpl must exist"

test_start "critical_zshenv_exists_toplevel"
assert_file_exists "$REPO_ROOT/dot_zshenv" "dot_zshenv must exist at repo root"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
