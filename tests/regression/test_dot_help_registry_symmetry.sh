#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Symmetry ratchet between bin/dot's three static registries:
#   * _dot_command_routes()  — every command the dispatcher can route
#   * _dot_help_specs()      — every command shown in the compact overview
#   * _dot_help_details()    — every command with a detailed body
#
# `_dot_help_summary()` reads details first, then falls back to specs.
# So a command with only a specs entry still works — this test does
# NOT require details entries for every spec.
#
# What this test catches (that test_dot_subcommand_smoke.sh doesn't):
#
#   1. Phantom help topics: entries in _dot_help_specs or
#      _dot_help_details that don't map to any real route (leftover
#      after a route was renamed/removed).
#   2. Functional drift: `dot help <cmd>` actually invoked for every
#      routed command; must not return "Unknown help topic" (soft —
#      HIDDEN_FROM_HELP exemption matches the smoke test).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

# Sandbox HOME to keep help invocations off real user state.
sandbox="$(mktemp -d -t help-symmetry.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox" \
  XDG_CONFIG_HOME="$sandbox/.config" \
  XDG_DATA_HOME="$sandbox/.local/share" \
  XDG_CACHE_HOME="$sandbox/.cache" \
  XDG_STATE_HOME="$sandbox/.local/state" \
  CHEZMOI_SOURCE_DIR="$REPO_ROOT"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# ---------------------------------------------------------------------------
# Extract the 3 registries.
# ---------------------------------------------------------------------------
routes=()
while IFS= read -r line; do routes+=("$line"); done < <(
  awk '/^_dot_command_routes\(\)/,/^\}/' "$DOT_CLI" |
    awk -F'|' '/^[a-z][a-z0-9-]*\|[a-z]+$/ { print $1 }' |
    sort -u
)

specs=()
while IFS= read -r line; do specs+=("$line"); done < <(
  awk '/^_dot_help_specs\(\)/,/^\}/' "$DOT_CLI" |
    awk -F'|' 'NF >= 2 && $2 ~ /^[a-z][a-z0-9-]*$/ { print $2 }' |
    sort -u
)

details=()
while IFS= read -r line; do details+=("$line"); done < <(
  awk '/^_dot_help_details\(\)/,/^\}/' "$DOT_CLI" |
    awk -F'|' '$1 ~ /^[a-z][a-z0-9-]*$/ { print $1 }' |
    sort -u
)

declare -A ROUTES=()
for c in "${routes[@]}"; do ROUTES["$c"]=1; done

# ---------------------------------------------------------------------------
# 0. Sanity: parsers found entries.
# ---------------------------------------------------------------------------
test_start "route_table_nonempty"
if [[ ${#routes[@]} -ge 30 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: %d routes\n' "$CURRENT_TEST" "${#routes[@]}"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: only %d routes — parser broken?\n' "$CURRENT_TEST" "${#routes[@]}"
fi

test_start "help_tables_nonempty"
if [[ ${#specs[@]} -ge 30 && ${#details[@]} -ge 30 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: %d specs + %d details\n' "$CURRENT_TEST" "${#specs[@]}" "${#details[@]}"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: specs=%d details=%d\n' "$CURRENT_TEST" "${#specs[@]}" "${#details[@]}"
fi

# ---------------------------------------------------------------------------
# 1. Phantom entries — help text for a topic no route can dispatch.
# ---------------------------------------------------------------------------
test_start "no_phantom_help_specs"
phantom_specs=()
for c in "${specs[@]}"; do
  [[ -z "${ROUTES[$c]:-}" ]] && phantom_specs+=("$c")
done
if [[ ${#phantom_specs[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${phantom_specs[*]}"
fi

test_start "no_phantom_help_details"
phantom_details=()
for c in "${details[@]}"; do
  [[ -z "${ROUTES[$c]:-}" ]] && phantom_details+=("$c")
done
if [[ ${#phantom_details[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${phantom_details[*]}"
fi

# ---------------------------------------------------------------------------
# 2. Functional gate — `dot help <cmd>` must not return "Unknown"
#    for any routed command. Uses the same HIDDEN_FROM_HELP exemption
#    as tests/regression/test_dot_subcommand_smoke.sh for consistency.
# ---------------------------------------------------------------------------
HIDDEN_FROM_HELP=(
  apply update scorecard attestation security-score
  health health-check smoke-test heal drift intelligence
  conflicts locks log-rotate alias-check setup setup-mode
  load-bench-pty
  agents init registry manual patterns
)

_is_hidden() {
  local n="$1"
  local h
  for h in "${HIDDEN_FROM_HELP[@]}"; do
    [[ "$h" == "$n" ]] && return 0
  done
  return 1
}

test_start "dot_help_cmd_works_for_every_visible_command"
broken=()
skipped=0
for cmd in "${routes[@]}"; do
  # Meta routes never take `dot help`
  case "$cmd" in
    help|--help|-h|version|--version|-v) continue ;;
  esac
  if _is_hidden "$cmd"; then
    skipped=$((skipped + 1))
    continue
  fi
  out="$(timeout 5 bash "$DOT_CLI" help "$cmd" 2>&1 || true)"
  # ANSI-strip the output before matching (help formatter emits color).
  clean="${out//$'\x1b'[??]*[mK]/}"
  if [[ "$clean" == *"Unknown help topic"* ]]; then
    broken+=("$cmd")
  fi
done
if [[ ${#broken[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  visible_count=$(( ${#routes[@]} - skipped - 6 ))
  printf '  \033[0;32m✓\033[0m %s: %d visible commands answered, %d hidden skipped\n' \
    "$CURRENT_TEST" "$visible_count" "$skipped"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: Unknown help topic for: %s\n' "$CURRENT_TEST" "${broken[*]}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
