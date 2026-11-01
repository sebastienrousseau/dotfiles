#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The route cache (P2.1): lib/dot/names.sh builds the command table from the
# route fragments into $XDG_CACHE_HOME/dot/cli/commands.txt and reads it back
# while it is fresh. Each case runs names.sh in a child bash against a copy
# of the tree, and probes the table for a record planted in one place only,
# so a case can tell the cache from a rebuild from the fallback.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-route-cache.XXXXXX")"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

# tree DIR: the parts of the source tree the table needs.
tree() {
  mkdir -p "$1/lib/dot/data"
  cp "$REPO_ROOT/lib/dot/table-merge.awk" "$1/lib/dot/"
  cp "$REPO_ROOT/lib/dot/data/groups.txt" "$REPO_ROOT/lib/dot/data/commands.txt" "$1/lib/dot/data/"
  for f in "$REPO_ROOT"/plugins/*/commands.txt; do
    mkdir -p "$1/plugins/$(basename "$(dirname "$f")")"
    cp "$f" "$1/plugins/$(basename "$(dirname "$f")")/"
  done
}

# probe SRC CACHE VERSION KEY: "yes" when the table SRC loads has a dom
# record for KEY, "no" when not; extra env as further arguments.
probe() {
  local src="$1" cache="$2" version="$3" key="$4"
  shift 4
  env "$@" XDG_CACHE_HOME="$cache" bash -c '
    set -euo pipefail # as bin/dot runs
    _DOT_SRC="$1" VERSION="$2"
    source "$3/lib/dot/names.sh"
    _dot_table_load
    if [[ "$_DOT_TABLE" == *$'"'"'\n'"'"'"dom|$4|"* ]]; then echo yes; else echo no; fi
  ' _ "$src" "$version" "$REPO_ROOT" "$key"
}

CACHE_FILE() { printf '%s/dot/cli/commands.txt' "$1"; }

SRC="$WORK/src"
tree "$SRC"
C="$WORK/cache"

test_start "a_cold_load_builds_the_cache"
assert_equals "yes" "$(probe "$SRC" "$C" 1.0.0 theme)" "the table has the theme domain"
assert_file_exists "$(CACHE_FILE "$C")" "the cache is written"
assert_equals "dot-cli-table/2|1.0.0|$SRC|lib/dot/data/groups.txt plugins/agent/commands.txt" \
  "$(head -1 "$(CACHE_FILE "$C")" | cut -d' ' -f1-2)" "its first line is the key: format, version, tree, fragments"
grep -v '^#' "$SRC/lib/dot/data/commands.txt" >"$WORK/table"
assert_equals "" "$(tail -n +2 "$(CACHE_FILE "$C")" | diff "$WORK/table" -)" "its body is the merged table"

# A record only the cache holds: seen while the cache is fresh, gone after
# a rebuild. The cache is dated after every fragment.
plant() {
  printf 'dom|planted|show||only in the cache\n' >>"$(CACHE_FILE "$C")"
  touch -d '+1 minute' "$(CACHE_FILE "$C")" 2>/dev/null || touch -A 0100 "$(CACHE_FILE "$C")"
}

test_start "a_fresh_cache_is_read_not_rebuilt"
plant
assert_equals "yes" "$(probe "$SRC" "$C" 1.0.0 planted)" "the planted record is read from the cache"

test_start "a_newer_fragment_rebuilds_it"
plant
touch -d '+2 minutes' "$SRC/plugins/theme/commands.txt" 2>/dev/null || touch -A 0200 "$SRC/plugins/theme/commands.txt"
assert_equals "no" "$(probe "$SRC" "$C" 1.0.0 planted)" "an edited fragment is merged again"
assert_equals "0" "$(grep -c '^dom|planted|' "$(CACHE_FILE "$C")")" "and the cache is rewritten without the planted record"
assert_equals "yes" "$(probe "$SRC" "$C" 1.0.0 theme)" "with the real table"

# Release archives date every file 1970; an upgrade must still rebuild.
test_start "an_upgrade_rebuilds_it_whatever_the_mtimes"
probe "$SRC" "$C" 1.0.0 theme >/dev/null
plant
find "$SRC" -type f -exec touch -d '@0' {} + 2>/dev/null || find "$SRC" -type f -exec touch -t 197001010000 {} +
assert_equals "yes" "$(probe "$SRC" "$C" 1.0.0 planted)" "same version, older files: the cache stands"
assert_equals "no" "$(probe "$SRC" "$C" 1.0.1 planted)" "a new version: rebuilt"
assert_equals "dot-cli-table/2|1.0.1" "$(head -1 "$(CACHE_FILE "$C")" | cut -d'|' -f1-2)" "and the cache is rewritten for it"

test_start "an_empty_cache_is_rebuilt"
: >"$(CACHE_FILE "$C")"
touch -d '+3 minutes' "$(CACHE_FILE "$C")" 2>/dev/null || touch -A 0300 "$(CACHE_FILE "$C")"
assert_equals "yes" "$(probe "$SRC" "$C" 1.0.1 theme)" "a cache with no key is not read as an empty table"

test_start "another_tree_rebuilds_it"
OTHER="$WORK/other"
tree "$OTHER"
probe "$SRC" "$C" 1.0.0 theme >/dev/null
plant
assert_equals "no" "$(probe "$OTHER" "$C" 1.0.0 planted)" "a cache built for one tree is not read for another"
assert_equals "dot-cli-table/2|1.0.0|$OTHER" "$(head -1 "$(CACHE_FILE "$C")" | cut -d'|' -f1-3)" "and is replaced with its own"

test_start "help_reads_but_never_writes_the_cache"
H="$WORK/help-cache"
assert_equals "yes" "$(probe "$SRC" "$H" 1.0.0 theme _DOT_TABLE_READONLY=1)" "the table loads"
assert_file_not_exists "$(CACHE_FILE "$H")" "no cache is written under --help"

test_start "an_unwritable_cache_dir_still_loads_the_table"
RO="$WORK/ro-cache"
mkdir -p "$RO"
chmod a-w "$RO"
assert_equals "yes" "$(probe "$SRC" "$RO" 1.0.0 theme)" "the table loads from the merge alone"
assert_file_not_exists "$(CACHE_FILE "$RO")" "and nothing is written"
chmod u+w "$RO"

# A cache file that cannot be replaced (here a directory in its place): the
# merge is used from memory and no temporary file is left behind.
test_start "a_failed_replace_leaves_no_temporary_file"
STUCK="$WORK/stuck-cache"
mkdir -p "$STUCK/dot/cli/commands.txt"
chmod a-w "$STUCK/dot/cli/commands.txt"
assert_equals "yes" "$(probe "$SRC" "$STUCK" 1.0.0 theme)" "the table loads"
assert_equals "" "$(find "$STUCK/dot/cli" -maxdepth 1 -name 'commands.txt.*' -print)" "no temporary file is left"
chmod u+w "$STUCK/dot/cli/commands.txt"

# A tree with no fragments, or a merge that fails, reads the generated table.
test_start "a_tree_without_fragments_reads_the_generated_table"
BARE="$WORK/bare"
tree "$BARE"
rm -f "$BARE"/plugins/*/commands.txt
printf 'dom|generated|show||only in commands.txt\n' >>"$BARE/lib/dot/data/commands.txt"
assert_equals "yes" "$(probe "$BARE" "$WORK/bare-cache" 1.0.0 generated)" "commands.txt is read"
assert_file_not_exists "$(CACHE_FILE "$WORK/bare-cache")" "and nothing is cached"

test_start "a_failed_merge_falls_back_to_the_generated_table"
BROKEN="$WORK/broken"
tree "$BROKEN"
printf 'this is not awk {\n' >"$BROKEN/lib/dot/table-merge.awk"
printf 'dom|generated|show||only in commands.txt\n' >>"$BROKEN/lib/dot/data/commands.txt"
assert_equals "yes" "$(probe "$BROKEN" "$WORK/broken-cache" 1.0.0 generated)" "commands.txt stands in"
assert_file_not_exists "$(CACHE_FILE "$WORK/broken-cache")" "and a failed merge is not cached"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
