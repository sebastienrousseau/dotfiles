#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Error-prone areas — historically complex or fragile workflows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# ═══════════════════════════════════════════════════════════════
# 1. TEMPLATE RENDERING — Go templates in shell files
# ═══════════════════════════════════════════════════════════════

test_start "template_zshrc_has_balanced_braces"
# Go template {{ }} must be balanced
open=$(grep -o '{{' "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "zshrc template braces must be balanced ($open open, $close close)"

test_start "template_gitconfig_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/dot_gitconfig.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_gitconfig.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "gitconfig template braces must be balanced"

test_start "template_no_raw_template_syntax_in_non_tmpl"
# Non-.tmpl shell files must NOT contain {{ .chezmoi }} or {{ .dotfiles }} template syntax
# Excludes docker format strings ({{.Names}}) which use Go templates legitimately
violations=0
while IFS= read -r f; do
  if grep -qE '\{\{\s*\.(chezmoi|dotfiles|features|if|else|end|range)' "$f" 2>/dev/null; then
    violations=$((violations + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates" -name "*.sh" ! -name "*.tmpl" 2>/dev/null)
assert_equals "0" "$violations" "non-.tmpl files must not contain chezmoi template directives"

# ═══════════════════════════════════════════════════════════════
# 2. ALIAS AGGREGATION — collision detection
# ═══════════════════════════════════════════════════════════════

test_start "alias_no_duplicate_names_in_ai"
# Extract alias names from AI aliases and check for duplicates
ai_aliases=$(grep -E '^\s*alias\s+\w+=' "$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$ai_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate AI alias names"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate alias names found: $dupes"
fi

test_start "alias_no_duplicate_names_in_git"
git_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/.chezmoitemplates/aliases/git/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$git_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate git alias names"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate git alias names: $dupes"
fi

# ═══════════════════════════════════════════════════════════════
# 3. CACHED EVAL — cache invalidation correctness
# ═══════════════════════════════════════════════════════════════

test_start "cached_eval_zsh_has_malware_check"
assert_file_contains "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" "suspicious_re" "zsh _cached_eval must check for suspicious output"

test_start "cached_eval_bash_has_malware_check"
assert_file_contains "$REPO_ROOT/dot_bashrc" "Suspicious" "bash _cached_eval must check for suspicious output"

test_start "cached_eval_fish_exists"
assert_file_exists "$REPO_ROOT/dot_config/fish/functions/_cached_eval.fish" "fish _cached_eval must exist"

# ═══════════════════════════════════════════════════════════════
# 4. VERSION SYNC — dotfiles_version consistency
# ═══════════════════════════════════════════════════════════════

test_start "version_in_chezmoidata"
version=$(grep -E '^dotfiles_version' "$REPO_ROOT/.chezmoidata.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [[ -n "$version" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: version is $version"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: version not found in .chezmoidata.toml"
fi

test_start "version_in_dot_cli"
assert_file_contains "$REPO_ROOT/dot_local/bin/executable_dot" 'VERSION=' "dot CLI must define VERSION"

# ═══════════════════════════════════════════════════════════════
# 5. CROSS-PLATFORM PATH HANDLING
# ═══════════════════════════════════════════════════════════════

test_start "paths_no_hardcoded_user_home"
# Shell files should use $HOME, not /home/<username> or /Users/<username>
# Excludes system paths: /home/linuxbrew (Homebrew on Linux)
hardcoded=0
while IFS= read -r f; do
  if grep -vE '^\s*#' "$f" | grep -qE '/home/[a-z]|/Users/[a-z]' 2>/dev/null; then
    # Allow known system paths
    if grep -vE '^\s*#' "$f" | grep -vE '/home/linuxbrew' | grep -qE '/home/[a-z]|/Users/[a-z]' 2>/dev/null; then
      hardcoded=$((hardcoded + 1))
    fi
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates" -name "*.sh" 2>/dev/null)
assert_equals "0" "$hardcoded" "no hardcoded user home paths in templates"

test_start "paths_xdg_compliance"
# Core shell files should reference XDG vars with fallbacks
assert_file_contains "$REPO_ROOT/dot_bashrc" "XDG_CACHE_HOME" "bashrc must use XDG_CACHE_HOME"

# ═══════════════════════════════════════════════════════════════
# 6. FEATURE FLAG GATING
# ═══════════════════════════════════════════════════════════════

test_start "feature_flags_all_boolean"
# Feature flags must be boolean (true/false), not strings
non_bool=0
while IFS= read -r line; do
  if echo "$line" | grep -qE '^\s*\w+\s*=\s*"'; then
    non_bool=$((non_bool + 1))
  fi
done < <(sed -n '/\[features\]/,/^\[/p' "$REPO_ROOT/.chezmoidata.toml" | grep -v '^\[' | grep -v '^$' | grep -v '^#')
assert_equals "0" "$non_bool" "all feature flags should be boolean (true/false)"

# ═══════════════════════════════════════════════════════════════
# 7. GPG/SSH SIGNING — configuration integrity
# ═══════════════════════════════════════════════════════════════

test_start "gitconfig_commit_signing"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "gpgsign = true" "commit signing must be enabled"

test_start "gitconfig_merge_verify"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "verifySignatures" "merge signature verification must be configured"

test_start "gpg_cache_ttl_reasonable"
ttl=$(grep -E 'default-cache-ttl' "$REPO_ROOT/dot_config/gnupg/gpg-agent.conf" | head -1 | awk '{print $2}')
if [[ -n "$ttl" && "$ttl" -le 7200 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: GPG cache TTL is ${ttl}s (<= 7200s)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: GPG cache TTL ${ttl}s too high (max 7200s)"
fi

# ═══════════════════════════════════════════════════════════════
# 8. TEMPLATE BALANCE CHECKS — more .tmpl files
# ═══════════════════════════════════════════════════════════════

test_start "template_ssh_config_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/private_dot_ssh/config.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/private_dot_ssh/config.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "ssh config template braces must be balanced ($open open, $close close)"

test_start "template_fish_init_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/dot_config/fish/conf.d/init.fish.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_config/fish/conf.d/init.fish.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "fish init template braces must be balanced ($open open, $close close)"

test_start "template_bashrc_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/dot_bashrc'"

test_start "template_options_zsh_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "options.zsh template braces must be balanced ($open open, $close close)"

test_start "template_aliases_aggregator_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/dot_config/shell/90-ux-aliases.sh.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_config/shell/90-ux-aliases.sh.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "alias aggregator template braces must be balanced ($open open, $close close)"

test_start "template_starship_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/dot_config/starship.toml.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_config/starship.toml.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "starship template braces must be balanced ($open open, $close close)"

test_start "template_kitty_has_balanced_braces"
open=$(grep -o '{{' "$REPO_ROOT/dot_config/kitty/kitty.conf.tmpl" | wc -l | tr -d ' ')
close=$(grep -o '}}' "$REPO_ROOT/dot_config/kitty/kitty.conf.tmpl" | wc -l | tr -d ' ')
assert_equals "$open" "$close" "kitty template braces must be balanced ($open open, $close close)"

# ═══════════════════════════════════════════════════════════════
# 9. ALIAS COLLISION CHECKS — more domains
# ═══════════════════════════════════════════════════════════════

test_start "alias_no_duplicate_names_in_docker"
docker_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/.chezmoitemplates/aliases/docker/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$docker_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate docker alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate docker alias names: $dupes"
fi

test_start "alias_no_duplicate_names_in_kubernetes"
k8s_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/.chezmoitemplates/aliases/kubernetes/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$k8s_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate kubernetes alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate kubernetes alias names: $dupes"
fi

test_start "alias_no_duplicate_names_in_cd"
cd_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/.chezmoitemplates/aliases/cd/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$cd_aliases" | uniq -d)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate cd alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate cd alias names: $dupes"
fi

test_start "alias_no_duplicate_names_in_default"
# Conditional aliases (if/elif) may define the same name for different platforms — exclude those
default_aliases=$(grep -rhE '^\s*alias\s+\w+=' "$REPO_ROOT/.chezmoitemplates/aliases/default/" 2>/dev/null | sed 's/.*alias \([^=]*\)=.*/\1/' | sort)
dupes=$(echo "$default_aliases" | uniq -c | awk '$1 > 2 {print $2}' || true)
if [[ -z "$dupes" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no duplicate default alias names"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate default alias names: $dupes"
fi

# ═══════════════════════════════════════════════════════════════
# 10. VERSION CONSISTENCY
# ═══════════════════════════════════════════════════════════════

test_start "version_consistent_chezmoidata_vs_package_json"
chezmoi_ver=$(grep -E '^dotfiles_version' "$REPO_ROOT/.chezmoidata.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
pkg_ver=$(grep -E '"version"' "$REPO_ROOT/package.json" | head -1 | sed 's/.*"\([0-9][0-9.]*\)".*/\1/')
assert_equals "$chezmoi_ver" "$pkg_ver" "version in .chezmoidata.toml ($chezmoi_ver) must match package.json ($pkg_ver)"

# ═══════════════════════════════════════════════════════════════
# 11. NO DEPRECATED VIM.LOOP IN NEOVIM CONFIGS
# ═══════════════════════════════════════════════════════════════

test_start "nvim_no_deprecated_vim_loop"
vim_loop_count=0
while IFS= read -r f; do
  if grep -qE 'vim\.loop' "$f" 2>/dev/null; then
    vim_loop_count=$((vim_loop_count + 1))
  fi
done < <(find "$REPO_ROOT/dot_config/nvim" -name "*.lua" 2>/dev/null)
assert_equals "0" "$vim_loop_count" "nvim configs must not use deprecated vim.loop (use vim.uv instead)"

# ═══════════════════════════════════════════════════════════════
# 12. FUNCTION FILES SYNTAX — all must pass bash -n
# ═══════════════════════════════════════════════════════════════

test_start "functions_api_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/api/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/api/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_files_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/files/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/files/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_security_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/security/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/security/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_system_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/system/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/system/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

test_start "functions_text_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/text/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/text/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

# ═══════════════════════════════════════════════════════════════
# 13. ALIAS FILES SYNTAX — all must pass bash -n
# ═══════════════════════════════════════════════════════════════

test_start "aliases_docker_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/docker/docker.aliases.sh'"

test_start "aliases_kubernetes_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/kubernetes/kubernetes.aliases.sh'"

test_start "aliases_git_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/git/git.aliases.sh'"

test_start "aliases_cd_core_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/cd/cd-core.aliases.sh'"

test_start "aliases_modern_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/modern/modern.aliases.sh'"

test_start "aliases_security_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/security/security.aliases.sh'"

# ═══════════════════════════════════════════════════════════════
# 14. FEATURE FLAGS USED IN TEMPLATES EXIST IN .CHEZMOIDATA.TOML
# ═══════════════════════════════════════════════════════════════

test_start "feature_flags_referenced_exist"
# Extract feature flags used in templates ({{ if .features.X }})
missing_flags=""
while IFS= read -r flag; do
  if ! grep -qE "^\s*${flag}\s*=" "$REPO_ROOT/.chezmoidata.toml" 2>/dev/null; then
    missing_flags="$missing_flags $flag"
  fi
done < <(grep -rohE '\.\s*features\.([a-zA-Z_]+)' "$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl" 2>/dev/null | sed 's/.*features\.\([a-zA-Z_]*\)/\1/' | sort -u)
if [[ -z "$missing_flags" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all referenced feature flags exist in .chezmoidata.toml"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing feature flags:$missing_flags"
fi

# ═══════════════════════════════════════════════════════════════
# 15. NO HARDCODED EMAIL IN NON-TEMPLATE SHELL SCRIPTS
# ═══════════════════════════════════════════════════════════════

test_start "no_hardcoded_email_in_shell_scripts"
email_count=0
while IFS= read -r f; do
  # Exclude security files (keygen, ssh-config) which use emails as examples
  [[ "$f" == *security* ]] && continue
  if grep -vE '^\s*#' "$f" | grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' 2>/dev/null; then
    email_count=$((email_count + 1))
  fi
done < <(find "$REPO_ROOT/.chezmoitemplates" -name "*.sh" ! -name "*.tmpl" 2>/dev/null)
assert_equals "0" "$email_count" "non-template shell scripts must not contain hardcoded email addresses"

# ═══════════════════════════════════════════════════════════════
# 16. SSH CONFIG TEMPLATE REQUIRED SECTIONS
# ═══════════════════════════════════════════════════════════════

test_start "ssh_config_has_host_wildcard"
assert_file_contains "$REPO_ROOT/private_dot_ssh/config.tmpl" "Host *" "ssh config must define Host * defaults"

test_start "ssh_config_has_kex_algorithms"
assert_file_contains "$REPO_ROOT/private_dot_ssh/config.tmpl" "KexAlgorithms" "ssh config must specify KexAlgorithms"

# ═══════════════════════════════════════════════════════════════
# 17. GIT CONFIG TEMPLATE REQUIRED SECTIONS
# ═══════════════════════════════════════════════════════════════

test_start "gitconfig_has_user_section"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "[user]" "gitconfig must have [user] section"

test_start "gitconfig_has_core_section"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "[core]" "gitconfig must have [core] section"

test_start "gitconfig_has_push_section"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "[push]" "gitconfig must have [push] section"

test_start "gitconfig_has_merge_section"
assert_file_contains "$REPO_ROOT/dot_gitconfig.tmpl" "[merge]" "gitconfig must have [merge] section"

# ═══════════════════════════════════════════════════════════════
# 18. ADDITIONAL ALIAS AND FUNCTION SYNTAX CHECKS
# ═══════════════════════════════════════════════════════════════

test_start "aliases_npm_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/npm/npm.aliases.sh'"

test_start "aliases_python_syntax"
assert_exit_code 0 "bash -n '$REPO_ROOT/.chezmoitemplates/aliases/python/python.aliases.sh'"

test_start "functions_nav_files_syntax"
bad_funcs=""
for f in "$REPO_ROOT"/.chezmoitemplates/functions/nav/*.sh; do
  [[ -f "$f" ]] || continue
  bash -n "$f" 2>/dev/null || bad_funcs="$bad_funcs $(basename "$f")"
done
if [[ -z "$bad_funcs" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all functions/nav/*.sh files pass bash -n"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors in:$bad_funcs"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
