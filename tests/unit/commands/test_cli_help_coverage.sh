#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Diagnostic ratchet for `dot help <cmd>` topic coverage.
#
# bin/dot has two authoritative tables:
#   * _dot_command_routes()  — every top-level `dot <cmd>` (denominator)
#   * _dot_help_specs()      — every command with a `dot help <cmd>`
#                              entry (numerator)
#
# The gap between them is "commands you can run but can't ask about."
# This test reports the gap and enforces a growing budget: the ratchet
# floor is HELP_COVERAGE_FLOOR (default: today's actual count) and any
# drop below that fails the run. Adding new help topics raises the
# floor on the next commit — no manual bump required.
#
# When _dot_help_specs() reaches parity with _dot_command_routes(),
# swap this diagnostic ratchet for the strict cli_no_partial_or_bare
# style seen in test_cli_docs_sync.sh.
#
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

BIN_DOT="$REPO_ROOT/bin/dot"

# ---------------------------------------------------------------------------
# Parse both tables.
# ---------------------------------------------------------------------------
mapfile -t ROUTES < <(
  awk '/^_dot_command_routes\(\)/,/^\}/' "$BIN_DOT" \
    | awk -F'|' '/^[a-z][a-z0-9-]*\|[a-z]+$/ { print $1 }' \
    | sort -u
)

mapfile -t HELP_TOPICS < <(
  # Field 2 is the topic name. Some description columns contain
  # literal `|` characters (option lists like `--ai|-A`), so we can't
  # rely on NF==4 — but field 2 is always a valid identifier, so
  # discriminate on its shape instead.
  awk '/^_dot_help_specs\(\)/,/^\}/' "$BIN_DOT" \
    | awk -F'|' 'NF>=2 && $2 ~ /^[a-z][a-z0-9-]*$/ { print $2 }' \
    | sort -u
)

declare -A HELP_SET=()
for t in "${HELP_TOPICS[@]}"; do HELP_SET["$t"]=1; done

# ---------------------------------------------------------------------------
# Partition.
# ---------------------------------------------------------------------------
covered=()
missing=()
for cmd in "${ROUTES[@]}"; do
  if [[ -n "${HELP_SET[$cmd]:-}" ]]; then
    covered+=("$cmd")
  else
    missing+=("$cmd")
  fi
done

total=${#ROUTES[@]}
have=${#covered[@]}
pct=$(( total > 0 ? have * 100 / total : 100 ))

# ---------------------------------------------------------------------------
# Print diagnostic table.
# ---------------------------------------------------------------------------
printf '  \033[1;36mRatchet\033[0m: %d of %d routed commands have a `dot help` entry (%d%%)\n' \
  "$have" "$total" "$pct"
if [[ ${#missing[@]} -gt 0 ]]; then
  printf '  \033[0;33mMissing help topics\033[0m: %s\n' "${missing[*]}"
fi
echo ""

# ---------------------------------------------------------------------------
# Assertions.
# ---------------------------------------------------------------------------
test_start "help_specs_table_has_entries"
if (( ${#HELP_TOPICS[@]} > 40 )); then
  _ok "found ${#HELP_TOPICS[@]} help topics"
else
  _fail "only ${#HELP_TOPICS[@]} help topics (expected > 40)"
fi

test_start "help_topics_are_all_routed_commands"
# The reverse direction: every help topic should refer to a real
# routed command (no help entries for phantom commands).
declare -A ROUTED_SET=()
for c in "${ROUTES[@]}"; do ROUTED_SET["$c"]=1; done
phantom=()
for t in "${HELP_TOPICS[@]}"; do
  [[ -z "${ROUTED_SET[$t]:-}" ]] && phantom+=("$t")
done
if [[ ${#phantom[@]} -eq 0 ]]; then
  _ok
else
  _fail "help topics with no matching route: ${phantom[*]}"
fi

# ---------------------------------------------------------------------------
# Growing-budget gate: coverage must not drop below the floor.
# As of 2026-08-28 the floor is 100 (all routed commands covered).
# Override in CI env via HELP_COVERAGE_FLOOR to relax temporarily.
# ---------------------------------------------------------------------------
FLOOR="${HELP_COVERAGE_FLOOR:-100}"
test_start "help_coverage_meets_growing_floor"
if (( have >= FLOOR )); then
  _ok "have=$have >= floor=$FLOOR"
else
  _fail "coverage dropped: have=$have < floor=$FLOOR"
fi

# ---------------------------------------------------------------------------
# Full-parity gate. Since we're at 100/100, enforce it: any newly-
# routed command that lands without a matching _dot_help_specs()
# entry fails the run.
# ---------------------------------------------------------------------------
test_start "help_coverage_at_full_parity_with_routes"
if [[ ${#missing[@]} -eq 0 ]]; then
  _ok
else
  _fail "routed commands with no help topic: ${missing[*]}"
fi

_cmd_finish
