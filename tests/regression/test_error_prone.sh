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
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: GPG cache TTL is ${ttl}s (<= 7200s)"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: GPG cache TTL ${ttl}s too high (max 7200s)"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
