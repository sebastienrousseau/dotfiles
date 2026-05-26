#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: 9140ddb
# Regression: every dot subcommand listed in the route table has help
# text and the dispatcher can find a backing module.
#
# The Phase 1-6 reorg moved command modules around. If a future
# refactor renames a module or drops it from the route table, this
# test makes it loud.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

# Sandbox HOME so commands that read user config don't pull from the
# real machine and so any speculative writes land in tmp.
sandbox="$(mktemp -d -t dot-smoke.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.config" "$sandbox/.local/share" "$sandbox/.cache" \
  "$sandbox/.local/state"
ln -s "$REPO_ROOT" "$sandbox/.dotfiles"
export HOME="$sandbox" \
  XDG_CONFIG_HOME="$sandbox/.config" \
  XDG_DATA_HOME="$sandbox/.local/share" \
  XDG_CACHE_HOME="$sandbox/.cache" \
  XDG_STATE_HOME="$sandbox/.local/state" \
  CHEZMOI_SOURCE_DIR="$REPO_ROOT"

# Extract the route table from bin/dot so this test is in lockstep
# with the dispatcher. Each line is `command|route`. We skip aliases
# that exist only to map flags (`--help`, `-h`, `--version`, `-v`)
# since `dot help <flag>` doesn't make sense.
mapfile -t routes < <(
  awk '/^_dot_command_routes\(\)/{flag=1; next}
       flag && /^EOF$/{exit}
       flag && /^[a-z][a-z_-]+\|/{print}' "$DOT_CLI"
)

test_start "route_table_parsed"
if [[ ${#routes[@]} -ge 30 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ${#routes[@]} commands in route table"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only ${#routes[@]} commands — parser broken?"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

# Commands intentionally hidden from the visible help surface
# (internal aliases, sub-dispatchers, deprecated entrypoints). They
# must still route to a real module, but they don't need a help entry.
HIDDEN_FROM_HELP=(
  # Aliases / alternate names for already-documented commands
  apply update scorecard attestation security-score
  # Health subroutines reachable through `dot doctor` or `dot health`
  health health-check smoke-test heal drift intelligence
  # Internal command-routing topics
  conflicts locks log-rotate alias-check setup setup-mode
  # AI-related sub-dispatchers that operate purely on routing
  load-bench-pty
  # Sub-dispatcher modules that print their own help when invoked
  agents init registry manual patterns
)

is_in() {
  local needle="$1"
  shift
  local v
  for v in "$@"; do
    [[ "$v" == "$needle" ]] && return 0
  done
  return 1
}

# Find the backing module file for a route name.
module_file() {
  local route="$1"
  case "$route" in
    init | agents | registry | manual | patterns | search | help | version) ;;
    *) printf '%s/scripts/dot/commands/%s.sh\n' "$REPO_ROOT" "$route" ;;
  esac
}

# Run dot help <cmd> with a generous timeout. The help system runs
# entirely in-process; no network or sudo involved.
help_text() {
  local cmd="$1"
  bash "$DOT_CLI" help "$cmd" 2>&1 || true
}

# 1) Every command in the route table must have a backing module.
missing_module=()
for line in "${routes[@]}"; do
  cmd="${line%%|*}"
  route="${line##*|}"
  mf="$(module_file "$route")"
  if [[ -n "$mf" && ! -f "$mf" ]]; then
    missing_module+=("$cmd → $mf")
  fi
done
test_start "every_route_has_backing_module"
if [[ ${#missing_module[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${#missing_module[@]} routes have no module file:"
  for m in "${missing_module[@]}"; do
    printf '%b\n' "    - $m"
  done
fi

# 2) Every routable command must have a per-command help entry under
#    `dot help <cmd>`. Hidden aliases / sub-dispatchers in HIDDEN_FROM_HELP
#    are exempt (they delegate to other commands). Everything else is
#    user-facing and must have content. Strict by design — the user
#    explicitly asked that all commands carry help.
unknown_topic=()
no_summary=()
for line in "${routes[@]}"; do
  cmd="${line%%|*}"
  case "$cmd" in --* | -? | version) continue ;; esac
  is_in "$cmd" "${HIDDEN_FROM_HELP[@]}" && continue

  out="$(help_text "$cmd")"
  if [[ "$out" == *"Unknown help topic"* ]]; then
    unknown_topic+=("$cmd")
  elif [[ "$out" != *"Summary"* ]]; then
    no_summary+=("$cmd")
  fi
done

test_start "every_visible_command_has_help_entry"
if [[ ${#unknown_topic[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: every visible command resolves under \`dot help\`"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${#unknown_topic[@]} commands have no help entry:"
  for c in "${unknown_topic[@]}"; do
    printf '%b\n' "    - $c"
  done
fi

test_start "every_visible_command_has_summary"
if [[ ${#no_summary[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: every visible command shows a Summary line"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${#no_summary[@]} commands lack Summary content:"
  for c in "${no_summary[@]}"; do
    printf '%b\n' "    - $c"
  done
fi

# 3) Top-level CLI invariants: `dot`, `dot help`, `dot help all`, `dot --version`.
test_start "dot_no_args_shows_help"
out="$(bash "$DOT_CLI" 2>&1 || true)"
if [[ "$out" == *"What it is"* ]] || [[ "$out" == *"USAGE"* ]] || [[ "$out" == *"Reference"* ]] || [[ "$out" == *"Start"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${out:0:120}"
fi

test_start "dot_help_all_lists_commands"
out="$(bash "$DOT_CLI" help all 2>&1 || true)"
hits=0
for keyword in theme doctor sync ai secrets fonts; do
  [[ "$out" == *"$keyword"* ]] && ((hits++)) || true
done
if [[ $hits -ge 5 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $hits/6 expected commands listed"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: only $hits/6 keywords found"
fi

test_start "dot_version_prints_version"
out="$(bash "$DOT_CLI" --version 2>&1 || true)"
if [[ "$out" == *"0.2.503"* ]] || [[ "$out" == *"Dotfiles"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${out:0:120}"
fi

test_start "dot_unknown_command_errors"
out="$(bash "$DOT_CLI" __nonexistent_command_xyzzy__ 2>&1 || true)"
if [[ "$out" == *"Unknown"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${out:0:120}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
