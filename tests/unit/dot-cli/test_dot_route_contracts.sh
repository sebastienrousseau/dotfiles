#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Contracts for the two routing helpers in bin/dot, found by mutation testing:
#   _dot_command_route — an empty or unknown command name is a miss: no
#     module printed AND a nonzero status (mutant B2 made the empty-name
#     early exit report success);
#   _has_help_flag — the `--` sentinel ends the scan without matching, so
#     `dot <cmd> -- ...` must reach the command, never the help intercept
#     (mutant B3 made `--` itself trigger the intercept).
# The route helper is pulled out of bin/dot by name (the dispatcher cannot
# be sourced without running) and executed in a fresh bash; the sentinel is
# exercised end to end through `dot version`, whose output is cheap and
# distinct from the `dot help version` topic.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-route.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Pull one top-level function out of bin/dot, by name.
_extract_fn() {
  awk -v fn="$1" '
    $0 ~ "^" fn "\\(\\) \\{" {
      print
      if ($0 ~ /\}[ \t]*$/) exit # a one-line function
      inside = 1
      next
    }
    inside { print }
    inside && /^\}/ { exit }
  ' "$DOT_CLI"
}
{
  printf '_DOT_SRC=%q\n' "$REPO_ROOT"
  _extract_fn _dot_data
  _extract_fn _dot_command_routes
  _extract_fn _dot_command_route
} >"$WORK/route.sh"

# route <name> — run _dot_command_route in a fresh bash; stdout to $WORK/out.
route() {
  "$BASH_BIN" -c "source '$WORK/route.sh'; _dot_command_route \"\$1\"" _ "$1" >"$WORK/out" 2>&1
}

# dot <args...> — run the CLI in a sandboxed HOME; stdout+stderr to $WORK/out.
dot() {
  mkdir -p "$WORK/home"
  HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" \
    XDG_DATA_HOME="$WORK/home/.local/share" XDG_CACHE_HOME="$WORK/home/.cache" \
    XDG_STATE_HOME="$WORK/home/.local/state" CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    NO_COLOR=1 "$BASH_BIN" "$DOT_CLI" "$@" >"$WORK/out" 2>&1
}

test_start "route_known_name_prints_module_and_succeeds"
rc=0
route version || rc=$?
assert_equals "0" "$rc" "known command exits 0"
assert_equals "version" "$(cat "$WORK/out")" "module name printed"

test_start "route_empty_name_is_a_miss"
rc=0
route "" || rc=$?
assert_equals "1" "$rc" "empty name exits 1 (mutant B2: returned 0)"
assert_equals "" "$(cat "$WORK/out")" "nothing printed for an empty name"

test_start "route_unknown_name_is_a_miss"
rc=0
route no-such-command-xyz || rc=$?
assert_equals "1" "$rc" "unknown name exits 1"
assert_equals "" "$(cat "$WORK/out")" "nothing printed for an unknown name"

test_start "clean_cache_routes_to_core"
# The weekly dotfiles-maintenance systemd timer runs `dot clean-cache`;
# core.sh implements it, so the route table must send it there.
rc=0
route clean-cache || rc=$?
assert_equals "0" "$rc" "clean-cache is a known route"
assert_equals "core" "$(cat "$WORK/out")" "clean-cache routes to the core module"

test_start "clean_cache_runs_end_to_end"
mkdir -p "$WORK/home/.cache/zsh"
touch "$WORK/home/.cache/zsh/stale-init.zsh"
rc=0
dot clean-cache || rc=$?
assert_equals "0" "$rc" "dot clean-cache exits 0 (the maintenance timer's command)"
assert_output_not_contains "Unknown command" "cat '$WORK/out'" "not rejected as unknown"
if [[ -e "$WORK/home/.cache/zsh/stale-init.zsh" ]]; then stale=present; else stale=removed; fi
assert_equals "removed" "$stale" "the stale zsh init cache was cleared"

test_start "double_dash_alone_does_not_trigger_help_intercept"
dot version -- literal || true
assert_file_contains "$WORK/out" "Dotfiles Version" "command ran (mutant B3: -- routed to help)"
assert_output_not_contains "Summary" "cat '$WORK/out'" "help topic not rendered"

test_start "help_flag_after_double_dash_is_a_literal_argument"
dot version -- --help || true
assert_file_contains "$WORK/out" "Dotfiles Version" "command ran, --help after -- is data"
assert_output_not_contains "Summary" "cat '$WORK/out'" "help topic not rendered"

test_start "help_flag_before_double_dash_still_intercepts"
dot version --help -- || true
assert_file_contains "$WORK/out" "dot version" "help topic rendered"
assert_file_contains "$WORK/out" "Summary" "help topic body rendered"
assert_output_not_contains "Dotfiles Version" "cat '$WORK/out'" "command itself did not run"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
