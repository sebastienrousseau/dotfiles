#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

MISE_CONFIG="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"
FISH_ENV="$REPO_ROOT/defaults/dot_config/fish/conf.d/env.fish.tmpl"
ZSH_TARGET="$REPO_ROOT/defaults/dot_config/zsh/rc.d/35-rust-target.zsh.tmpl"
CARGO_CONFIG="$REPO_ROOT/defaults/dot_cargo/config.toml.tmpl"
THEMING_DOC="$REPO_ROOT/docs/guides/THEMING.md"

test_start "build_cache_has_one_xdg_root"
assert_file_contains "$MISE_CONFIG" 'DOT_BUILD_ROOT = "{{ xdg_cache_home }}/dot/builds"' "mise defines the private build root once"

test_start "build_cache_consumers_use_root"
failures=0
for variable in GOCACHE PIP_CACHE_DIR UV_CACHE_DIR ZIG_LOCAL_CACHE_DIR ZIG_GLOBAL_CACHE_DIR; do
  grep -Fq "$variable = \"{{ env.DOT_BUILD_ROOT }}/" "$MISE_CONFIG" || failures=$((failures + 1))
done
assert_equals "0" "$failures" "managed cache variables derive from DOT_BUILD_ROOT"

test_start "build_cache_avoids_shared_tmp"
assert_output_not_contains "/tmp/builds" "cat '$MISE_CONFIG' '$FISH_ENV' '$ZSH_TARGET' '$CARGO_CONFIG' '$THEMING_DOC'"

test_start "fish_build_cache_is_private"
assert_file_contains "$FISH_ENV" 'mkdir -p -m 700 "$DOT_BUILD_ROOT"' "Fish creates the build root with owner-only permissions"

test_start "zsh_build_cache_is_private"
assert_file_contains "$ZSH_TARGET" 'umask 077 && command mkdir -p "$DOT_BUILD_ROOT"' "Zsh creates the build root with an owner-only umask"

test_start "rust_target_name_rejects_traversal"
assert_file_contains "$ZSH_TARGET" 'name must contain only letters, digits, dot, underscore, or hyphen' "Rust target aliases reject path separators and traversal names"

test_start "zsh_build_cache_runtime_contract"
if command -v zsh >/dev/null 2>&1; then
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-build-cache.XXXXXX")"
  trap 'rm -rf "$WORK"' EXIT
  mkdir -p "$WORK/project"
  touch "$WORK/project/Cargo.toml"
  # zsh -f and no inherited ZDOTDIR/DOT_BUILD_ROOT: otherwise the caller's
  # own zshenv or build root leaks in and the root lands outside $WORK.
  runtime_root="$(env -u ZDOTDIR -u DOT_BUILD_ROOT XDG_CACHE_HOME="$WORK/cache" HOME="$WORK/home" zsh -f -c 'source "$1"; print -r -- "$DOT_BUILD_ROOT"' zsh "$ZSH_TARGET")"
  runtime_mode="$(stat -c '%a' "$runtime_root" 2>/dev/null || stat -f '%Lp' "$runtime_root")"
  if env -u ZDOTDIR -u DOT_BUILD_ROOT XDG_CACHE_HOME="$WORK/cache" HOME="$WORK/home" zsh -f -c 'source "$1"; cd "$2"; ! rust-target-tmp "../escape" >/dev/null 2>&1 && [[ ! -e target ]]' zsh "$ZSH_TARGET" "$WORK/project"; then
    assert_equals "$WORK/cache/dot/builds:700" "$runtime_root:$runtime_mode" "Zsh creates a private XDG root and rejects traversal at runtime"
  else
    assert_equals "rejected" "accepted" "Zsh must reject traversal without creating a target link"
  fi
else
  assert_equals "unavailable" "unavailable" "Zsh runtime contract skipped when zsh is unavailable"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
