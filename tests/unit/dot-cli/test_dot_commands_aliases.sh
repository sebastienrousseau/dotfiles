#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI aliases commands (extracted module)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

ALIASES_FILE="$REPO_ROOT/scripts/dot/commands/aliases.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: aliases.sh file exists
test_start "aliases_cmd_file_exists"
assert_file_exists "$ALIASES_FILE" "aliases.sh should exist"

# Test: aliases.sh is valid shell syntax
test_start "aliases_cmd_syntax_valid"
if bash -n "$ALIASES_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: aliases.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: aliases.sh has syntax errors"
fi

# Test: defines cmd_aliases
test_start "aliases_cmd_defines_aliases"
assert_file_contains "$ALIASES_FILE" "cmd_aliases" "defines cmd_aliases function"

# Test: defines cmd_alias_check
test_start "aliases_cmd_defines_alias_check"
assert_file_contains "$ALIASES_FILE" "cmd_alias_check" "defines cmd_alias_check function"

# Test: defines alias_manifest_path
test_start "aliases_cmd_defines_manifest_path"
assert_file_contains "$ALIASES_FILE" "alias_manifest_path" "defines alias_manifest_path function"

# Test: defines emit_alias_manifest
test_start "aliases_cmd_defines_emit_manifest"
assert_file_contains "$ALIASES_FILE" "emit_alias_manifest" "defines emit_alias_manifest function"

# Test: has strict mode
test_start "aliases_cmd_strict_mode"
assert_file_contains "$ALIASES_FILE" "set -euo pipefail" "should use strict mode"

# Test: handles all subcommands
test_start "aliases_cmd_subcommands"
assert_file_contains "$ALIASES_FILE" "list)" "should handle list subcommand"
assert_file_contains "$ALIASES_FILE" "search)" "should handle search subcommand"
assert_file_contains "$ALIASES_FILE" "why)" "should handle why subcommand"
assert_file_contains "$ALIASES_FILE" "stats)" "should handle stats subcommand"
assert_file_contains "$ALIASES_FILE" "tiers)" "should handle tiers subcommand"

echo ""
echo "Aliases commands tests completed."

test_start "aliases_cmd_deep_branches_execute"
aliases_tmp="$DOTFILES_COV_TMPDIR/aliases-deep"
mkdir -p "$aliases_tmp/repo/scripts/diagnostics" \
  "$aliases_tmp/repo/scripts/dot/data" \
  "$aliases_tmp/repo/docs" \
  "$aliases_tmp/home/.config/shell/custom" \
  "$aliases_tmp/home/.config/zsh"
cat >"$aliases_tmp/repo/scripts/diagnostics/aliases-manifest.sh" <<'SHIM'
#!/usr/bin/env bash
cat <<'EOF'
ll	ls -la	default.aliases.sh	10
gs	git status	git.aliases.sh	20
danger	rm -rf --one-file-system	security.aliases.sh	30
EOF
SHIM
chmod +x "$aliases_tmp/repo/scripts/diagnostics/aliases-manifest.sh"
cat >"$aliases_tmp/repo/scripts/diagnostics/aliases-cheatsheet.sh" <<'SHIM'
#!/usr/bin/env bash
printf '# Alias Cheatsheet\n\n- ll\n'
SHIM
chmod +x "$aliases_tmp/repo/scripts/diagnostics/aliases-cheatsheet.sh"
cat >"$aliases_tmp/repo/scripts/dot/data/alias-deprecations.tsv" <<'EOF'
# alias	replacement	remove_in	note
oldll	ll	v0.3.0	use ll instead
EOF
cat >"$aliases_tmp/history" <<'EOF'
: 1784645600:0;ll
gs
ll /tmp
unknown
EOF
cat >"$aliases_tmp/home/.config/shell/90-ux-aliases.sh" <<'EOF'
alias c='clear'
alias q='exit'
alias e='${EDITOR:-vi}'
alias l='ls'
alias ll='ls -la'
alias la='ls -A'
alias lr='ls -R'
alias lra='ls -RA'
alias lt='ls -t'
alias lta='ls -tA'
alias h='history'
alias a='alias'
alias d='dirs'
alias _='sudo'
alias i='install'
EOF
# shellcheck disable=SC2016
printf 'source "$HOME/.config/shell/custom/auto_ls.zsh"\n' \
  >"$aliases_tmp/home/.config/zsh/.zshrc"
printf '# auto ls\n' >"$aliases_tmp/home/.config/shell/custom/auto_ls.zsh"

(
  set +e
  export HOME="$aliases_tmp/home"
  export HISTFILE="$aliases_tmp/history"
  export DOTFILES_ALIAS_PROFILE="minimal"
  export DOTFILES_ALIAS_ECOSYSTEMS="python,node"
  export DOTFILES_ALIAS_BUCKETS="system"
  export DOTFILES_SECURITY_MODE="strict"
  export DOTFILES_ENABLE_DANGEROUS_ALIASES="0"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  # shellcheck disable=SC1091
  source "$ALIASES_FILE"
  _DOT_SOURCE_DIR_CACHE="$aliases_tmp/repo"
  alias_manifest_path
  emit_alias_manifest
  cmd_aliases list
  cmd_aliases search git
  cmd_aliases search nomatch
  cmd_aliases why ll
  cmd_aliases why oldll
  cmd_aliases why missing
  cmd_aliases stats
  cmd_aliases cheatsheet
  cmd_aliases tiers
  DOTFILES_ALIAS_ECOSYSTEMS="all" DOTFILES_ALIAS_BUCKETS="system,svn" cmd_aliases tiers
  cmd_aliases unknown
  cmd_alias_check
) >/dev/null || true
assert_file_exists "$aliases_tmp/repo/docs/ALIASES_CHEATSHEET.md" \
  "aliases deep branches generated sandbox cheatsheet"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$ALIASES_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
