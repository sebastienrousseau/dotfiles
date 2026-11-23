#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF_FILE="$REPO_ROOT/defaults/dot_config/fish/conf.d/env.fish.tmpl"

test_start "fish_conf_env_has_path_exists"
assert_file_exists "$CONF_FILE" "env.fish.tmpl should exist"

test_start "fish_conf_env_has_path_not_empty"
if [[ -s "$CONF_FILE" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: not empty"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not be empty"
fi

test_start "fish_conf_env_has_path_construction"
if grep -q 'set -p PATH' "$CONF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: contains PATH construction"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should contain PATH construction"
fi

# The system dirs end up in the order 00-core-paths.sh gives bash and zsh
# (/usr/bin, /bin, /usr/sbin, /sbin), whatever order the parent left them in.
# On a merged-/usr distro they are one directory, but tools that record the
# path they were run from (mise writes it into every shim) must see the same
# one in every shell, or each shell's reshim breaks the other's shims.
FISH_BIN="$(command -v fish || true)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# From the exports the dir list reads ($PIPX_BIN_DIR, $BUN_INSTALL): without
# them "$BUN_INSTALL/bin" is /bin, which would be moved ahead of /usr/bin.
PATH_BLOCK="$WORK/path-block.fish"
sed -n '/^set -gx PIPX_HOME/,/^# Promote mise/p' "$CONF_FILE" | sed '/^{{/d' >"$PATH_BLOCK"
for start in "/bin:/usr/bin" "/sbin:/usr/sbin:/bin:/usr/bin" "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"; do
  test_start "fish_conf_env_system_dirs_follow_core_paths_from_${start//[:\/]/_}"
  if [[ -z "$FISH_BIN" ]]; then
    assert_true "true" "fish not installed; skipped"
    continue
  fi
  # shellcheck disable=SC2016 # fish code, expanded by fish
  got="$(env -i HOME="$WORK" PATH="$start" "$FISH_BIN" --no-config -c \
    'source $argv[1]; for p in $PATH; contains -- $p /usr/bin /bin /usr/sbin /sbin; and echo $p; end' \
    "$PATH_BLOCK" 2>&1 | tr '\n' ' ')"
  want=""
  for d in /usr/bin /bin /usr/sbin /sbin; do
    [[ -d "$d" ]] && want+="$d "
  done
  assert_equals "$want" "$got" "system dirs from $start"
done

# User dirs the parent already put on PATH (a terminal started from a login
# session passes ~/.cargo/bin, ~/.local/bin and the mise shims in) still end
# up ahead of the system dirs. Skipping a dir because it was present left it
# wherever the parent had it, behind the /usr/bin the block above moves to the
# front: /usr/bin/rustc then shadowed rustup and every mise shim.
UHOME="$WORK/home"
mkdir -p "$UHOME/.local/share/mise/shims" "$UHOME/bin" "$UHOME/.local/bin" "$UHOME/.cargo/bin"
SHIMS="$UHOME/.local/share/mise/shims"
for start in \
  "$SHIMS:$UHOME/bin:$UHOME/.cargo/bin:$UHOME/.local/bin:/usr/bin:/bin" \
  "/usr/bin:/bin:$UHOME/.cargo/bin:$SHIMS" \
  "/usr/bin:/bin"; do
  label="${start//$UHOME/~}"
  test_start "fish_conf_env_user_dirs_ahead_of_system_from_${label//[:\/~.]/_}"
  if [[ -z "$FISH_BIN" ]]; then
    assert_true "true" "fish not installed; skipped"
    continue
  fi
  # shellcheck disable=SC2016 # fish code, expanded by fish
  got="$(env -i HOME="$UHOME" PATH="$start" "$FISH_BIN" --no-config -c \
    'source $argv[1]; for p in $PATH; contains -- $p $argv[2..]; and echo $p; end' \
    "$PATH_BLOCK" "$SHIMS" "$UHOME/bin" "$UHOME/.local/bin" "$UHOME/.cargo/bin" /usr/bin 2>&1 |
    tr '\n' ' ')"
  want="$SHIMS $UHOME/bin $UHOME/.local/bin $UHOME/.cargo/bin "
  [[ -d /usr/bin ]] && want+="/usr/bin "
  assert_equals "$want" "$got" "user dirs from $label"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
