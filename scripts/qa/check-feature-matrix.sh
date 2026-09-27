#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# check-feature-matrix.sh — drift gate for docs/reference/FEATURE-MATRIX.md.
#
# The matrix is a contract: every user-facing feature of the `dot` CLI has a
# row naming the regression test, benchmark, example and manual section that
# cover it. A contract nobody checks rots, so this script checks it, and
# ci.yml runs it on every push.
#
# Four checks:
#
#   1. Command coverage — every command the dispatcher can route (bin/dot's
#      route table, which is what `scripts/dot/commands/*.sh` are reached
#      through) and every command in the generated docs/manual/command-index.md
#      has at least one row.
#   2. Test coverage — every regression test function named in a row is
#      defined by one of tests/regression/test_feature_matrix_*.sh.
#   3. Benchmark coverage — every benchmark id named in a row is produced by
#      `benches/dot_command_bench.sh --list-ids`.
#   4. Example coverage — every example file named in a row exists and is
#      executable by scripts/qa/validate-examples.sh.
#
# Usage:
#   scripts/qa/check-feature-matrix.sh [--quiet]
#
# Exit codes:
#   0  the matrix is in sync
#   1  drift detected (details on stderr)
#   2  bad invocation, or a file the gate depends on is missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$REPO_ROOT"

MATRIX="docs/reference/FEATURE-MATRIX.md"
DOT_BIN="bin/dot"
COMMAND_INDEX="docs/manual/command-index.md"
BENCH="benches/dot_command_bench.sh"
TEST_GLOB="tests/regression/test_feature_matrix_*.sh"

QUIET=0
_fm_parse_args() {
  case "${1:-}" in
    --quiet | -q) QUIET=1 ;;
    -h | --help)
      sed -n '5,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    "") ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
}

say() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$*"; }

_fm_require_files() {
  local required
  for required in "$MATRIX" "$DOT_BIN" "$COMMAND_INDEX" "$BENCH"; do
    if [[ ! -f "$required" ]]; then
      printf '::error::required file missing: %s\n' "$required" >&2
      exit 2
    fi
  done
}

failures=0
fail() {
  printf '::error::%s\n' "$1" >&2
  failures=$((failures + 1))
}

# _fm_fail_lines <prefix> <newline-separated items>: one failure per item.
_fm_fail_lines() {
  local prefix="$1" item
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    fail "$prefix$item"
  done <<<"$2"
}

# count <file>: its line count, without wc's padding.
count() { wc -l <"$1" | tr -d ' '; }

# ---------------------------------------------------------------------------
# Parse the matrix.
#
# Rows look like:
#   | `dot fleet apply` | --dry-run | `test_fm_x` | `run:y` | `examples/z.sh` | `docs/…` | regression |
#
# Field 1 is the command (backticked, "dot " prefix), 3 the test function,
# 4 the benchmark id, 5 the example path. The two explanatory tables at the
# top of the document have different shapes and are skipped by requiring a
# leading "| `dot ".
# ---------------------------------------------------------------------------
_fm_parse_matrix() {
  local row_count
  awk '
    # A cell may legitimately contain an escaped pipe (a variant like
    # "set advisory\|strict"). Neutralise those BEFORE splitting on "|", or the
    # row shifts a column and every later check reads the wrong cell.
    /^\| `dot / {
      line = $0
      gsub(/\\\|/, "\002", line)
      n = split(line, cell, "|")
      # 7 content columns become 9 fields: the empty strings either side of the
      # leading and trailing pipes. The document also carries a 3-column summary
      # table of the unmeasurable rows, which must not be parsed as feature rows.
      if (n < 9) next
      for (i = 1; i <= n; i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", cell[i])
        gsub(/`/, "", cell[i])
        gsub(/\002/, "|", cell[i])
      }
      # cell[2] command, cell[4] test, cell[5] bench, cell[6] example, cell[8] coverage
      print cell[2] "\t" cell[4] "\t" cell[5] "\t" cell[6] "\t" cell[8]
    }
  ' "$MATRIX" >"$work/rows.tsv"

  row_count="$(count "$work/rows.tsv")"
  if [[ "$row_count" -lt 50 ]]; then
    fail "only $row_count rows parsed from $MATRIX — has the table format changed?"
    exit 1
  fi

  # The command cell is "dot <command>"; a row may name a subcommand
  # ("dot fleet apply"), so the routable command is the first word after "dot".
  cut -f1 "$work/rows.tsv" | sed 's/^dot  *//' | awk '{print $1}' |
    sort -u >"$work/matrix-commands.txt"
  cut -f2 "$work/rows.tsv" | sort -u | grep -v '^$' >"$work/matrix-tests.txt"
  cut -f3 "$work/rows.tsv" | sort -u | grep -v '^$' >"$work/matrix-benches.txt"
  cut -f4 "$work/rows.tsv" | sort -u | grep -v '^$' >"$work/matrix-examples.txt"

  say "Feature matrix: $row_count rows, $(count "$work/matrix-commands.txt") distinct commands"
}

# ---------------------------------------------------------------------------
# 1. Command coverage
# ---------------------------------------------------------------------------
_fm_check_commands() {
  local missing_routed missing_indexed phantom
  # bin/dot's route table is the authority on what the dispatcher can reach.
  # Flag aliases (--help/-h/--version/-v) are not commands and are excluded.
  awk '/^_dot_command_routes\(\)/,/^EOF$/' "$DOT_BIN" |
    awk -F'|' '/^[a-z][a-z0-9-]*\|[a-z]+$/ { print $1 }' |
    sort -u >"$work/routed.txt"

  # The generated command index is the documented surface.
  grep -oE '^\| `dot [a-z][a-z0-9-]*' "$COMMAND_INDEX" |
    sed 's/^| `dot //' | sort -u >"$work/indexed.txt"

  missing_routed="$(comm -23 "$work/routed.txt" "$work/matrix-commands.txt")"
  if [[ -n "$missing_routed" ]]; then
    _fm_fail_lines "routable command has no FEATURE-MATRIX row: dot " "$missing_routed"
  else
    say "  ✓ every routable command has a row ($(count "$work/routed.txt") commands)"
  fi

  missing_indexed="$(comm -23 "$work/indexed.txt" "$work/matrix-commands.txt")"
  if [[ -n "$missing_indexed" ]]; then
    _fm_fail_lines "command documented in $COMMAND_INDEX has no FEATURE-MATRIX row: dot " "$missing_indexed"
  else
    say "  ✓ every documented command has a row ($(count "$work/indexed.txt") commands)"
  fi

  # A row naming a command the dispatcher cannot route is a phantom: the
  # feature was removed but its coverage claim was not.
  phantom="$(comm -13 <(sort -u "$work/routed.txt" "$work/indexed.txt") \
    "$work/matrix-commands.txt")"
  if [[ -n "$phantom" ]]; then
    _fm_fail_lines "FEATURE-MATRIX row names a command that is neither routable nor documented: dot " "$phantom"
  else
    say "  ✓ no phantom command rows"
  fi
}

# ---------------------------------------------------------------------------
# 2. Test coverage
# ---------------------------------------------------------------------------
_fm_check_tests() {
  local undefined orphan_count
  # `|| true`: under `set -euo pipefail` an unmatched glob (or a grep that
  # simply finds nothing) would abort the whole script with grep's status
  # before the emptiness check below can run — exit 2 and not a word about
  # why, instead of the diagnostic that check exists to print.
  # shellcheck disable=SC2086
  grep -ho '^test_fm_[a-z0-9_]*()' $TEST_GLOB 2>/dev/null |
    sed 's/()//' | sort -u >"$work/defined-tests.txt" || true

  if [[ ! -s "$work/defined-tests.txt" ]]; then
    fail "no test functions found in $TEST_GLOB"
    return 0
  fi
  undefined="$(comm -23 "$work/matrix-tests.txt" "$work/defined-tests.txt")"
  if [[ -n "$undefined" ]]; then
    _fm_fail_lines "FEATURE-MATRIX names a test function that does not exist: " "$undefined"
  else
    say "  ✓ every named test function exists ($(count "$work/matrix-tests.txt") referenced, $(count "$work/defined-tests.txt") defined)"
  fi

  # A defined-but-unreferenced test is not an error — it may be a helper or a
  # cross-cutting invariant — but it is worth surfacing so coverage does not
  # quietly drift out of the table.
  orphan_count="$(comm -13 "$work/matrix-tests.txt" "$work/defined-tests.txt" | grep -c . || true)"
  if [[ "$orphan_count" -gt 0 ]]; then
    say "  · $orphan_count test function(s) defined but not referenced by any row"
  fi
}

# Every function the matrix names must also actually be CALLED by its file;
# a defined-but-never-invoked test passes vacuously.
_fm_check_called() {
  local fn uncalled=0
  while IFS= read -r fn; do
    [[ -n "$fn" ]] || continue
    # shellcheck disable=SC2086
    if ! grep -hqE "^[[:space:]]*${fn}([[:space:]]|$)" $TEST_GLOB 2>/dev/null; then
      fail "test function is defined but never called: $fn"
      uncalled=$((uncalled + 1))
    fi
  done <"$work/matrix-tests.txt"
  if [[ "$uncalled" -eq 0 ]]; then
    say "  ✓ every named test function is invoked by its file"
  fi
}

# ---------------------------------------------------------------------------
# 3. Benchmark coverage
# ---------------------------------------------------------------------------

# Cold-start coverage must be total: one help benchmark per routable command.
_fm_check_cold_start() {
  local cmd missing_bench=0
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    if ! grep -qx "help:$cmd" "$work/bench-ids.txt"; then
      fail "no cold-start benchmark for routable command: dot $cmd"
      missing_bench=$((missing_bench + 1))
    fi
  done <"$work/routed.txt"
  if [[ "$missing_bench" -eq 0 ]]; then
    say "  ✓ every routable command has a cold-start benchmark"
  fi
}

_fm_check_benches() {
  local unknown_bench
  if ! bash "$BENCH" --list-ids >"$work/bench-ids.txt" 2>/dev/null ||
    [[ ! -s "$work/bench-ids.txt" ]]; then
    fail "could not list benchmark ids: $BENCH --list-ids"
    return 0
  fi
  sort -u -o "$work/bench-ids.txt" "$work/bench-ids.txt"
  unknown_bench="$(comm -23 "$work/matrix-benches.txt" "$work/bench-ids.txt")"
  if [[ -n "$unknown_bench" ]]; then
    _fm_fail_lines "FEATURE-MATRIX names a benchmark id the harness does not produce: " "$unknown_bench"
  else
    say "  ✓ every named benchmark id exists ($(count "$work/matrix-benches.txt") referenced, $(count "$work/bench-ids.txt") available)"
  fi
  _fm_check_cold_start
}

# ---------------------------------------------------------------------------
# 4. Example coverage
# ---------------------------------------------------------------------------
_fm_check_examples() {
  local path missing_example=0
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ ! -f "$path" ]]; then
      fail "FEATURE-MATRIX names an example that does not exist: $path"
      missing_example=$((missing_example + 1))
    elif [[ "$path" != examples/*.sh ]]; then
      fail "example is outside the directory validate-examples.sh runs: $path"
      missing_example=$((missing_example + 1))
    fi
  done <"$work/matrix-examples.txt"
  if [[ "$missing_example" -eq 0 ]]; then
    say "  ✓ every named example exists ($(count "$work/matrix-examples.txt") referenced)"
  fi
}

# Every command module should be demonstrated by at least one example.
_fm_check_modules() {
  local module name missing_group=0
  for module in scripts/dot/commands/*.sh; do
    [[ -f "$module" ]] || continue
    name="$(basename "$module" .sh)"
    if ! grep -rqlE "scripts/dot/commands/${name}\.sh" examples/ 2>/dev/null; then
      fail "no example references the command module: $module"
      missing_group=$((missing_group + 1))
    fi
  done
  if [[ "$missing_group" -eq 0 ]]; then
    say "  ✓ every command module is referenced by an example"
  fi
}

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
_fm_verdict() {
  if [[ "$failures" -ne 0 ]]; then
    printf '\nFEATURE-MATRIX drift: %s problem(s).\n' "$failures" >&2
    printf 'Add or correct the row(s) in %s, then re-run this check.\n' "$MATRIX" >&2
    exit 1
  fi
  say ""
  say "FEATURE-MATRIX is in sync."
}

_fm_main() {
  _fm_parse_args "$@"
  _fm_require_files
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  _fm_parse_matrix
  _fm_check_commands
  _fm_check_tests
  _fm_check_called
  _fm_check_benches
  _fm_check_examples
  _fm_check_modules
  _fm_verdict
}

_fm_main "$@"
exit 0
