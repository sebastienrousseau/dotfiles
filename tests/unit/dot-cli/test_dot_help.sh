#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# `dot help` from the command table (ADR-020, N0.4, lib/dot/help.sh): the
# overview lists every domain under its group and every shortcut, `dot help
# all` every spelling once, `dot help <spelling>` and `dot <spelling> --help`
# one domain, object or command with its flags, and `dot help --json` the
# catalog. Everything is checked against lib/dot/data/commands.txt. The
# help routing (`--help` after a spelling, shortcuts) is lib/dot/names.sh's.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TABLE="$REPO_ROOT/lib/dot/data/commands.txt"
BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-help.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# dot ARGS...: run the CLI in a sandboxed HOME; stdout to out, stderr to err.
dot() {
  HOME="$WORK" XDG_STATE_HOME="$WORK/state" NO_COLOR=1 TERM=dumb \
    "$BASH_BIN" "${DOT_BIN:-$REPO_ROOT/bin/dot}" "$@" >"$WORK/out" 2>"$WORK/err" </dev/null
}
# field TYPE N: field N of every TYPE record in the table.
field() { awk -F'|' -v t="$1" -v n="$2" '$1 == t { print $n }' "$TABLE"; }

test_start "overview_lists_every_domain_by_group"
rc=0
dot help || rc=$?
assert_equals "0" "$rc" "dot help exits 0"
missing=""
while read -r d; do
  grep -qE "^  $d +" "$WORK/out" || missing="$missing $d"
done < <(field dom 2)
assert_equals "" "$missing" "every domain is listed"
assert_file_contains "$WORK/out" "TRUST & HOSTS" "under its group title"
missing=""
while read -r s; do
  grep -qE "^  $s +dot " "$WORK/out" || missing="$missing $s"
done < <(awk -F'|' '$1 == "alias" && $3 == "shortcut" { print $2 }' "$TABLE")
assert_equals "" "$missing" "every shortcut is listed with its target"
assert_output_not_contains "upgrade" "cat '$WORK/out'" "no deprecated name"

test_start "help_all_lists_every_spelling_once"
dot help all
want="$(field cmd 2 | wc -l | tr -d ' ')"
got="$(grep -cE '^  dot ' "$WORK/out")"
assert_equals "$want" "$got" "one line per command"
assert_equals "" "$(grep -E '^  dot ' "$WORK/out" | awk '{print $2, $3, $4}' | sort | uniq -d)" "none twice"
assert_equals "$(field dom 2 | wc -l | tr -d ' ')" "$(grep -cE '^dot [a-z]+$' "$WORK/out")" "one heading per domain"
assert_not_empty "$(grep -E 'dot secret key list .*\(planned\)' "$WORK/out")" "a planned command is marked"

test_start "command_help_shows_effect_route_and_flags"
rc=0
dot help doctor perf show || rc=$?
assert_equals "0" "$rc" "exits 0"
assert_file_contains "$WORK/out" "dot doctor perf show · Startup timings" "its summary"
assert_file_contains "$WORK/out" "effect     read" "its effect"
assert_file_contains "$WORK/out" "runs       dot-doctor perf show, the plugin's entry" "the entry that runs it"
assert_not_empty "$(grep -E -- '--runs, -r <count> +Number of runs' "$WORK/out")" "its flags, with the value they take"
dot help secret key list
assert_file_contains "$WORK/out" "planned, not built yet" "a planned command says so"

test_start "domain_help_lists_only_its_commands"
rc=0
dot help system || rc=$?
assert_equals "0" "$rc" "dot help <domain> exits 0"
assert_output_not_contains "dot config apply" "cat '$WORK/out'" "no other domain's commands"
assert_equals "" "$(grep 'dot system update ' "$WORK/out" | grep -F '(planned)')" "a built command is not marked planned"
assert_not_empty "$(grep 'dot system clean ' "$WORK/out" | grep -F '(planned)')" "a planned one is"
rc=0
dot secret || rc=$?
assert_equals "0" "$rc" "a domain alone whose default is planned lists its commands"
assert_file_contains "$WORK/out" "dot secret · secrets" "under its heading"
rc=0
dot help system schedule || rc=$?
assert_equals "0" "$rc" "dot help <object> exits 0"

test_start "help_flag_is_the_same_help"
dot help secret set
want="$(cat "$WORK/out")"
rc=0
dot secret set MY_KEY --yes --help || rc=$?
assert_equals "0" "$rc" "exits 0 without running the command"
assert_equals "$want" "$(cat "$WORK/out")" "dot <spelling> ARGS --help is dot help <spelling>"
rc=0
dot doctor -h || rc=$?
assert_equals "0" "$rc" "a domain's -h exits 0"
assert_file_contains "$WORK/out" "dot doctor · health, repair, backup and rollback" "a domain's -h lists its commands"
dot system schedule --help
assert_file_contains "$WORK/out" "dot system schedule · scheduled maintenance jobs" "so does an object's"

test_start "a_shortcut_shows_its_target"
dot help status
assert_file_contains "$WORK/out" "dot config status ·" "dot help status is dot help config status"
assert_file_contains "$WORK/out" "dot status is short for dot config status" "and says so"
rc=0
dot update --help || rc=$?
assert_equals "0" "$rc" "exits 0"
assert_file_contains "$WORK/out" "dot system update ·" "and update --help, system update's"
assert_file_contains "$WORK/out" "dot update is short for dot system update" "naming the shortcut"
dot doctor check --help
assert_output_not_contains "short for" "cat '$WORK/out'" "a spelling that is not a shortcut says nothing of the kind"
# An old name inside its deprecation window: the dispatcher pinned to
# 0.2.537, so the case does not depend on the release under test.
source "$SCRIPT_DIR/../../framework/pinned_dot.sh"
rc=0
DOT_BIN="$(pinned_dot "$WORK/pinned" 0.2.537)" dot cache-refresh --help || rc=$?
assert_equals "0" "$rc" "an old name's --help still shows its help"
assert_output_not_contains "dot shell update ·" "cat '$WORK/out'" "its old help, not the domain help"

test_start "json_catalog"
rc=0
dot help --json || rc=$?
assert_equals "0" "$rc" "exits 0"
assert_true "cmp -s '$WORK/out' '$REPO_ROOT/lib/dot/data/commands.json'" "prints lib/dot/data/commands.json"
assert_equals "cli/catalog.v1 17" "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["schema"], len(d["domains"]))' "$WORK/out")" "a versioned catalog of the 17 domains"

test_start "search_finds_new_and_old_names"
rc=0
dot help SECURITY || rc=$?
assert_equals "0" "$rc" "a term that matches exits 0"
assert_file_contains "$WORK/out" "dot security score show" "a command whose spelling matches, case-insensitively"
dot help scorecard
assert_file_contains "$WORK/out" "dot scorecard                    now dot doctor score, until" "an old name, with its new spelling"
dot help sync
assert_file_contains "$WORK/out" "dot config sync" "a shortcut shows its target"

test_start "an_unknown_term_finds_nothing"
rc=0
dot help zz-no-such-term || rc=$?
assert_equals "1" "$rc" "exits 1"

test_start "without_its_library_help_still_answers"
mkdir -p "$WORK/bare/bin" "$WORK/bare/home"
cp "$REPO_ROOT/bin/dot" "$WORK/bare/bin/dot"
rc=0
(cd "$WORK/bare" && HOME="$WORK/bare/home" "$BASH_BIN" bin/dot >"$WORK/out" 2>&1 </dev/null) || rc=$?
assert_equals "0" "$rc" "exits 0"
assert_file_contains "$WORK/out" "Usage: dot <domain> [object] <verb>" "the usage line"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
