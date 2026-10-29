#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/defaults/.chezmoitemplates/aliases/tmux"

test_start "alias_dir_exists"
assert_dir_exists "$ALIASES_DIR" "aliases directory should exist"

test_start "alias_files_valid"
invalid=0
shopt -s nullglob
for f in "$ALIASES_DIR"/*.sh; do
  [[ -f "$f" ]] && ! bash -n "$f" 2>/dev/null && ((invalid++))
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all valid"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $invalid invalid"
fi

test_start "alias_no_hardcoded_paths"
if grep -rqE '"/home/[a-z]+' "$ALIASES_DIR" 2>/dev/null; then
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# tmux_calls <command>: run <command> in bash with the tmux aliases loaded
# and a tmux stub that records its arguments and has no server running.
tmux_calls() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/bin"
  cat >"$sandbox/bin/tmux" <<EOF
#!/bin/sh
echo "\$*" >>"$sandbox/calls"
[ "\$1" != has-session ]
EOF
  chmod +x "$sandbox/bin/tmux"
  env -i HOME="$sandbox" PATH="$sandbox/bin:$PATH" ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    bash --norc --noprofile -c "shopt -s expand_aliases; . \"\$1\"; eval \"\$2\"" _ \
    "$ALIASES_DIR/tmux.aliases.sh" "$1" >/dev/null 2>&1
  sed "s|$sandbox|~|g" "$sandbox/calls" 2>/dev/null | tr '\n' '|'
  rm -rf "$sandbox"
}

test_start "tmux_tmr_reloads_deployed_config"
assert_equals "source-file ~/.config/tmux/tmux.conf|" "$(tmux_calls tmr)" \
  "tmr reloads the deployed ~/.config/tmux/tmux.conf"

test_start "tmux_tm_starts_without_missing_file"
assert_equals "has-session|new-session -d|attach|" "$(tmux_calls tm)" \
  "tm starts a session (tmux reads its own config) and attaches"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
