#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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

# run_aliases <var=value...> -- <args...>: run cmd_aliases in a subshell
# against the fixture; sets A_OUT (stdout+stderr) and A_RC.
run_aliases() {
  local -a envs=()
  while [[ "${1:-}" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  A_RC=0
  A_OUT="$(
    set +e
    export HOME="$aliases_tmp/home" HISTFILE="$aliases_tmp/history" NO_COLOR=1
    for kv in ${envs[@]+"${envs[@]}"}; do export "${kv?}"; done
    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/dot/utils.sh"
    # shellcheck disable=SC1091
    source "$ALIASES_FILE"
    _DOT_SOURCE_DIR_CACHE="$aliases_tmp/repo"
    cmd_aliases "$@" 2>&1
  )" || A_RC=$?
}

test_start "aliases_cmd_strict_mode"
assert_equals "errexit|pipefail" \
  "$(bash --norc --noprofile -c 'set +e +o pipefail; source "$1" >/dev/null 2>&1; [[ -o errexit ]] && printf errexit; [[ -o pipefail ]] && printf "|pipefail"' _ "$ALIASES_FILE")" \
  "sourcing the module turns on errexit and pipefail"

test_start "aliases_list"
run_aliases -- list
assert_true '[[ $A_RC == 0 && $A_OUT == *"gs"*"git status"*"git.aliases.sh:20"* && $A_OUT == *"ll"*"ls -la"*"default.aliases.sh:10"* ]]' \
  "list shows every manifest alias with its value and source"

test_start "aliases_search_hit"
run_aliases -- search git
assert_true '[[ $A_RC == 0 && $A_OUT == *"git status"* && $A_OUT != *"ls -la"* ]]' \
  "search git returns only the matching alias"

test_start "aliases_search_miss"
run_aliases -- search nomatch
assert_true '[[ $A_RC == 1 && $A_OUT == *"No matches"* ]]' "a search with no match exits 1"

test_start "aliases_why_known"
run_aliases -- why ll
assert_true '[[ $A_RC == 0 && $A_OUT == *"ls -la"* && $A_OUT == *"default.aliases.sh:10"* ]]' \
  "why explains an alias: value and source"

test_start "aliases_why_deprecated"
run_aliases -- why oldll
assert_true '[[ $A_RC == 0 && $A_OUT == *"Deprecated"* && $A_OUT == *"Replacement"*"ll"* && $A_OUT == *"v0.3.0"* ]]' \
  "why reports a deprecated alias, its replacement and removal version"

test_start "aliases_why_missing"
run_aliases -- why missing
assert_true '[[ $A_RC == 1 && $A_OUT == *"not found: missing"* ]]' "why on an unknown alias exits 1"

test_start "aliases_stats_counts_history"
run_aliases -- stats
assert_true '[[ $A_RC == 0 && $A_OUT =~ 2[[:space:]]+ll ]]' "stats counts alias use in history (ll twice)"

test_start "aliases_tiers_follow_settings"
run_aliases DOTFILES_ALIAS_ECOSYSTEMS=python DOTFILES_ALIAS_BUCKETS=system -- tiers
assert_true '[[ $A_RC == 0 && $A_OUT =~ python[[:space:]]+enabled && $A_OUT =~ rust[[:space:]]+disabled ]]' \
  "tiers reports enabled and disabled ecosystems from the settings"

test_start "aliases_unknown_subcommand"
run_aliases -- unknown
assert_true '[[ $A_RC != 0 && $A_OUT == *"Unknown aliases subcommand: unknown"* ]]' \
  "an unknown subcommand fails and names it"

echo ""
echo "Aliases commands tests completed."

test_start "aliases_cmd_deep_branches_execute"
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
