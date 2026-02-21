#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for strict alias policy mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DATA_FILE="$REPO_ROOT/.chezmoidata.toml"
ZSHRC_TMPL="$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl"
SAFETY_TMPL="$REPO_ROOT/dot_config/shell/05-core-safety.sh.tmpl"
APPLY_SCRIPT="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
CHEZMOI_LIB="$REPO_ROOT/install/lib/chezmoi.sh"
INTERACTIVE_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/interactive/interactive.aliases.sh"
DOCKER_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/docker/docker.aliases.sh"
GIT_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/git/git.aliases.sh"

test_start "strict_mode_default_false"
assert_file_contains "$DATA_FILE" "strict_mode = false" "strict mode should default to false in shared data"

test_start "strict_mode_exported_to_env"
assert_file_contains "$ZSHRC_TMPL" "DOTFILES_ALIAS_STRICT_MODE" "zsh template should export strict mode env var"

test_start "strict_mode_has_destruction_log"
assert_file_contains "$SAFETY_TMPL" "DOTFILES_DESTRUCTIVE_LOG" "strict mode should support destructive action logging"
assert_file_contains "$SAFETY_TMPL" ".dotfiles_destruction.log" "strict mode should default to ~/.dotfiles_destruction.log"

test_start "strict_apply_precheck_in_ops_script"
assert_file_contains "$APPLY_SCRIPT" "DOTFILES_ALIAS_STRICT_MODE" "apply script should check strict mode toggle"
assert_file_contains "$APPLY_SCRIPT" "DOTFILES_ALIAS_POLICY=strict" "apply script should enforce strict governance"

test_start "strict_apply_precheck_in_install_lib"
assert_file_contains "$CHEZMOI_LIB" "DOTFILES_ALIAS_STRICT_MODE" "install lib should check strict mode toggle"
assert_file_contains "$CHEZMOI_LIB" "DOTFILES_ALIAS_POLICY=strict" "install lib should enforce strict governance"

test_start "destructive_aliases_guarded_by_confirm"
assert_file_contains "$INTERACTIVE_ALIASES" "dot_confirm_destructive" "interactive destructive aliases should require confirmation"
assert_file_contains "$DOCKER_ALIASES" "dot_confirm_destructive" "docker destructive helpers should require confirmation"
assert_file_contains "$GIT_ALIASES" "dot_confirm_destructive" "git destructive helpers should require confirmation"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
