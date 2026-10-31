#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The checkout is wherever install.sh put it (SOURCE_DIR may move it off
# ~/.dotfiles), so the shells export it as DOTFILES_DIR from chezmoi's
# working tree, and the aliases and functions that run its files use that
# (P2.2 edge 5c). Each case runs the rendered env file or the alias file
# against a checkout that is not ~/.dotfiles.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-dotfiles-dir.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases"

# render TEMPLATE: the template as chezmoi renders it from this checkout.
render() {
  printf '{}\n' >"$WORK/chezmoi.json"
  (cd "$WORK" && chezmoi --config "$WORK/chezmoi.json" --source "$REPO_ROOT/defaults" \
    --destination "$WORK/home" --cache "$WORK/cache" \
    --persistent-state "$WORK/state.boltdb" execute-template <"$1")
}

if command -v chezmoi >/dev/null 2>&1; then
  test_start "bash_and_zsh_export_the_checkout"
  render "$REPO_ROOT/defaults/dot_config/shell/00-core-paths.sh.tmpl" >"$WORK/00-core-paths.sh"
  got="$(env -u DOTFILES_DIR HOME="$WORK/home" bash -c 'source "$1" >/dev/null 2>&1; printf %s "$DOTFILES_DIR"' _ "$WORK/00-core-paths.sh")"
  assert_equals "$REPO_ROOT" "$got" "DOTFILES_DIR is chezmoi's working tree, the checkout"
  got="$(DOTFILES_DIR=/srv/mine HOME="$WORK/home" bash -c 'source "$1" >/dev/null 2>&1; printf %s "$DOTFILES_DIR"' _ "$WORK/00-core-paths.sh")"
  assert_equals "/srv/mine" "$got" "a DOTFILES_DIR already set is kept"
  got="$(env -u DOTFILES_DIR HOME="$WORK/home" bash -c 'source "$1" >/dev/null 2>&1; env | grep -c "^DOTFILES_DIR="' _ "$WORK/00-core-paths.sh")"
  assert_equals "1" "$got" "and exported to the commands the shell runs"

  if command -v fish >/dev/null 2>&1; then
    test_start "fish_exports_the_checkout"
    render "$REPO_ROOT/defaults/dot_config/fish/conf.d/env.fish.tmpl" >"$WORK/env.fish"
    got="$(env -u DOTFILES_DIR HOME="$WORK/home" fish --no-config -c 'source $argv[1] >/dev/null 2>&1; printf %s "$DOTFILES_DIR"' "$WORK/env.fish")"
    assert_equals "$REPO_ROOT" "$got" "fish sets the same checkout"
  fi

  if command -v zsh >/dev/null 2>&1; then
    test_start "zsh_no_longer_exports_a_dead_lib_path"
    render "$REPO_ROOT/defaults/dot_config/zsh/rc.d/10-env.zsh.tmpl" >"$WORK/10-env.zsh"
    got="$(env -u DOTFILES HOME="$WORK/home" zsh -fc 'source "$1" >/dev/null 2>&1; print -r -- "${DOTFILES-unset}"' _ "$WORK/10-env.zsh" 2>/dev/null)"
    assert_equals "unset" "$got" "DOTFILES (~/.dotfiles/lib, read by nothing) is gone"
  fi

  # bento.sh moved to lib/dot/ in the Phase 1 reorg; artifact mode still ran
  # scripts/dot/lib/bento.sh, which no longer exists, so it drew nothing.
  test_start "artifact_mode_runs_a_bento_that_exists"
  for tmpl in dot_config/zsh/dot_zshrc.tmpl dot_config/fish/conf.d/init.fish.tmpl; do
    script="$(render "$REPO_ROOT/defaults/$tmpl" | grep -o '[^" ]*/bento\.sh' | head -n 1)"
    script="${script//\$\{DOTFILES_DIR:-\$HOME\/.dotfiles\}/$REPO_ROOT}"
    script="${script//\$DOTFILES_DIR/$REPO_ROOT}"
    assert_file_exists "$script" "$tmpl runs the checkout's bento.sh"
  done
else
  echo "  (skip) chezmoi not available: env renders"
fi

# A checkout off ~/.dotfiles (with a space in its path), holding stand-ins
# for the scripts the aliases run: each prints which file ran.
CHECKOUT="$WORK/src/my dotfiles"
for f in scripts/diagnostics/doctor.sh install.sh scripts/ops/teleport.sh \
  scripts/security/lock-configs.sh; do
  mkdir -p "$CHECKOUT/$(dirname "$f")"
  printf 'echo "ran %s $*"\n' "$f" >"$CHECKOUT/$f"
done

# run FILE ALIAS: ALIAS's output after sourcing FILE in bash, with
# DOTFILES_DIR set to the checkout and HOME elsewhere.
run() {
  DOTFILES_DIR="$CHECKOUT" HOME="$WORK/home" bash -c '
    shopt -s expand_aliases
    source "$1" >/dev/null 2>&1
    eval "$2"' _ "$1" "$2" 2>&1
}

test_start "aliases_run_files_from_the_checkout"
assert_equals "ran scripts/diagnostics/doctor.sh " "$(run "$ALIASES/diagnostics/diagnostics.aliases.sh" dotdoc)" \
  "dotdoc runs the checkout's doctor"
assert_equals "ran install.sh " "$(run "$ALIASES/installer/installer.aliases.sh" dot-install)" \
  "dot-install runs the checkout's install.sh"
assert_equals "ran scripts/ops/teleport.sh " "$(run "$ALIASES/installer/installer.aliases.sh" telegram)" \
  "telegram runs the checkout's teleport.sh"

test_start "cd_aliases_go_to_the_checkout"
got="$(DOTFILES_DIR="$CHECKOUT" HOME="$WORK/home" bash -c 'source "$1" >/dev/null 2>&1; printf %s "$DOTF_DIR"' _ "$ALIASES/cd/cd-config.aliases.sh")"
assert_equals "$CHECKOUT" "$got" "DOTF_DIR (cd-config) is the checkout"
got="$(DOTFILES_DIR="$CHECKOUT" HOME="$WORK/home" bash -c 'source "$1" >/dev/null 2>&1; printf %s "$DOTF_DIR"' _ "$ALIASES/cd/cd.aliases.sh")"
assert_equals "$CHECKOUT" "$got" "DOTF_DIR (cd) is the checkout"

test_start "lock_configs_found_in_the_checkout"
assert_equals "ran scripts/security/lock-configs.sh lock" \
  "$(run "$ALIASES/security/immutability.aliases.sh" lock-configs)" \
  "lock-configs runs the checkout's script"

test_start "editrc_opens_the_checkout"
got="$(DOTFILES_DIR="$CHECKOUT" HOME="$WORK/home" EDITOR=echo bash -c 'source "$1" >/dev/null 2>&1; editrc alias; editrc dotfiles' _ "$ALIASES/editor/editor.aliases.sh")"
assert_equals "$CHECKOUT/defaults/.chezmoitemplates/aliases
$CHECKOUT" "$got" "editrc alias opens the alias sources, editrc dotfiles the checkout"

# The scripts that look for the checkout take DOTFILES_DIR, as the shells
# export it, before guessing ~/.dotfiles: here HOME has no ~/.dotfiles and
# chezmoi is not driving them.
# fresh SCRIPT ARGS...: SCRIPT's output and status (RC), DOTFILES_DIR the checkout.
fresh() {
  mkdir -p "$WORK/empty-home"
  RC=0
  OUT="$(env -u CHEZMOI_SOURCE_DIR DOTFILES_DIR="$REPO_ROOT" HOME="$WORK/empty-home" \
    PATH="/usr/bin:/bin" NO_COLOR=1 bash "$REPO_ROOT/$1" "${@:2}" 2>&1)" || RC=$?
}

test_start "diagnostics_take_the_checkout_from_dotfiles_dir"
fresh scripts/diagnostics/aliases-manifest.sh
assert_equals "0" "$RC" "aliases-manifest.sh finds a checkout off ~/.dotfiles"
assert_contains "dotdoc" "$OUT" "and lists the checkout's aliases"
fresh scripts/diagnostics/version-locks.sh
assert_equals "0" "$RC" "and so does version-locks.sh"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
