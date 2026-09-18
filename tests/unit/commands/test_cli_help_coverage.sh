#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Diagnostic ratchet for `dot help <cmd>` topic coverage.
#
# bin/dot has three authoritative tables:
#   * _dot_command_routes()  — every top-level `dot <cmd>` (denominator)
#   * _dot_help_specs()      — every command shown in the compact
#                              `dot help` overview
#   * _dot_help_details()    — every command with a summary/examples
#                              entry served by `dot help <cmd>`
#                              (this is what really has to be full)
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
# Enumerate every top-level command the user can dispatch — routes
# table entries PLUS bin/dot-* auto-shim executables. Since 2026-08-28
# bin/dot has a git-style fallthrough that execs dot-<name> when no
# route matches, so those are real user-facing commands and should
# have help entries too.
# ---------------------------------------------------------------------------
source "$SCRIPT_DIR/../../framework/docs_sync_helpers.sh"
mapfile -t ROUTES < <(_docs_extract_top_level_commands "$REPO_ROOT")

mapfile -t HELP_TOPICS < <(
  # _dot_help_details drives `dot help <cmd>` (via _dot_help_summary
  # and _dot_help_examples). Field 1 is the topic. Extra `|` in the
  # description or examples columns is fine; we only look at column 1.
  awk '/^_dot_help_details\(\)/,/^\}/' "$BIN_DOT" \
    | awk -F'|' '$1 ~ /^[a-z][a-z0-9-]*$/ { print $1 }' \
    | sort -u
)

mapfile -t HELP_OVERVIEW_TOPICS < <(
  # _dot_help_specs drives the compact `dot help` overview table.
  # Field 2 is the topic name. Description column may contain `|`.
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
test_start "help_details_table_has_entries"
if (( ${#HELP_TOPICS[@]} > 40 )); then
  _ok "found ${#HELP_TOPICS[@]} help detail entries"
else
  _fail "only ${#HELP_TOPICS[@]} entries (expected > 40)"
fi

test_start "help_overview_and_details_agree"
# Every command in the overview should also have a details entry
# so `dot help <cmd>` works after finding it in the overview.
declare -A DETAILS_SET=()
for t in "${HELP_TOPICS[@]}"; do DETAILS_SET["$t"]=1; done
overview_orphans=()
for t in "${HELP_OVERVIEW_TOPICS[@]}"; do
  [[ -z "${DETAILS_SET[$t]:-}" ]] && overview_orphans+=("$t")
done
if [[ ${#overview_orphans[@]} -eq 0 ]]; then
  _ok
else
  _fail "in overview but not in details: ${overview_orphans[*]}"
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
FLOOR="${HELP_COVERAGE_FLOOR:-${#ROUTES[@]}}"
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

# ---------------------------------------------------------------------------
# Functional gate. Actually run `dot help <cmd>` for every routed
# command and verify the process exits 0 AND emits non-trivial
# output that does NOT contain "Unknown help topic". Catches the
# real bug that inspired this whole ratchet: the entry looks
# present in one table but the runtime consults a different one.
# ---------------------------------------------------------------------------
test_start "dot_help_cmd_runs_for_every_routed_command"
broken=()
for cmd in "${ROUTES[@]}"; do
  # bin/dot help <cmd> should exit 0 with meaningful output.
  # Some routes are meta (help itself, version) — skip those.
  case "$cmd" in
    help|version|--version|-v|--help|-h) continue ;;
  esac
  out="$("$REPO_ROOT/bin/dot" help "$cmd" 2>&1)"
  rc=$?
  if (( rc != 0 )); then
    broken+=("${cmd}:exit=${rc}")
    continue
  fi
  # Strip ANSI escapes for the "Unknown" check.
  clean="${out//$'\x1b'[??]*[mK]/}"
  if [[ "$clean" == *"Unknown help topic"* ]]; then
    broken+=("${cmd}:unknown-topic")
    continue
  fi
  # Non-trivial output — must have at least 100 bytes after stripping.
  if (( ${#out} < 100 )); then
    broken+=("${cmd}:tiny-output(${#out}b)")
  fi
done
if [[ ${#broken[@]} -eq 0 ]]; then
  _ok "$(( ${#ROUTES[@]} - 6 )) commands answered dot help correctly"
else
  _fail "broken help topics: ${broken[*]}"
fi

_cmd_finish
