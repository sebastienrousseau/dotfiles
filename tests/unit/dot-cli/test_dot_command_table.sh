#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# ADR-020 names at runtime (N0.3): bin/dot resolves each `dot <domain>
# [object] <verb>` spelling through lib/dot/data/commands.txt to the route
# that runs it today, warns once per shell session on a deprecated name,
# exits 127 for a removed, expired or unknown one, and reads -V as the
# version and -v as --verbose.
# The resolver (lib/dot/names.sh) is sourced into a fresh bash for the unit
# cases; the rest goes end to end through the CLI in a sandboxed HOME.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
TABLE="$REPO_ROOT/lib/dot/data/commands.txt"
BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-names.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

printf '_DOT_SRC=%q\nVERSION=0.2.537\nsource %q\n' "$REPO_ROOT" \
  "$REPO_ROOT/lib/dot/names.sh" >"$WORK/names.sh"

# resolve <words...> — print "<route words>|<words replaced>".
resolve() {
  "$BASH_BIN" -c "source '$WORK/names.sh'; _dot_resolve \"\$@\"; printf '%s|%s\n' \"\$_RUN\" \"\$_RUN_USED\"" _ "$@"
}

# dot <args...> — run a CLI in a sandboxed HOME; stdout to out, stderr to err.
# DOT_BIN picks another copy of the dispatcher (the expiry tests).
dot() {
  mkdir -p "$WORK/home"
  HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" \
    XDG_DATA_HOME="$WORK/home/.local/share" XDG_CACHE_HOME="$WORK/home/.cache" \
    XDG_STATE_HOME="$WORK/home/.local/state" CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    NO_COLOR=1 TERM=dumb "$BASH_BIN" "${DOT_BIN:-$DOT_CLI}" "$@" \
    >"$WORK/out" 2>"$WORK/err" </dev/null
}

# A source tree whose table also removes `dot frob` and has `dot frob-old`
# past its release (no manifest does either today); bin/dot finds its lib/
# beside it.
mkdir -p "$WORK/src/bin"
cp -R "$REPO_ROOT/lib" "$WORK/src/lib"
cp "$DOT_CLI" "$WORK/src/bin/dot"
printf 'alias|frob|removed|doctor|\nalias|frob-old|deprecated|doctor|0.2.500\n' \
  >>"$WORK/src/lib/dot/data/commands.txt"

# names <words...> — print the command line _dot_names hands to routing.
names() {
  "$BASH_BIN" -c "source '$WORK/names.sh'; XDG_STATE_HOME='$WORK/state'; _dot_names \"\$@\"; echo \"\${_ARGV[*]}\"" _ "$@" 2>/dev/null
}

test_start "new_spellings_run_todays_routes"
assert_equals "upgrade|2" "$(resolve system update)" "dot system update runs dot upgrade"
assert_equals "update|2" "$(resolve config update)" "dot config update keeps the dotfiles-only update"
assert_equals "secrets set|2" "$(resolve secret set KEY)" "an object-less verb keeps its arguments"
assert_equals "tools|3" "$(resolve tool list --nix)" "a flagged alias target runs its old route"
assert_equals "env list|2" "$(resolve tool list)" "without the flag the plain verb runs"
assert_equals "ssh-key|3" "$(resolve secret key new)" "domain, object and verb"

test_start "shortcuts_and_flags_rewrite_the_command_line"
assert_equals "upgrade --yes" "$(names update --yes)" "dot update is dot system update (N7)"
assert_equals "status" "$(names status)" "dot status is dot config status"
assert_equals "version" "$(names -V)" "-V is the version"
assert_equals "upgrade" "$(names -v system update)" "-v passes the rest on"
assert_equals "upgrade" "$(names upgrade)" "a deprecated name keeps running its route"

test_start "defaults_and_old_subcommands"
assert_equals "doctor|1" "$(resolve doctor)" "a domain with its own route keeps its bare behaviour"
assert_equals "doctor|1" "$(resolve doctor --fix)" "a flag after the domain is still bare"
assert_equals "scorecard|2" "$(resolve doctor score)" "an object alone runs its default verb"
assert_equals "env|1" "$(resolve tool)" "a domain alone runs its own route first"
assert_equals "ai|1" "$(resolve ai tools)" "an old subcommand goes to the domain's own route"
assert_equals "cl|3" "$(resolve ai start claude)" "ai start <agent> launches that agent, not a one-shot prompt"

test_start "declared_but_not_built_resolves_to_nothing"
assert_equals "|0" "$(resolve system schedule set)" "a planned command is not run"
assert_equals "|0" "$(resolve system)" "a domain whose default is planned"
assert_equals "mode doctor|2" "$(resolve agent check)" "a domain with its own route runs the default verb's route only when bare has none"
assert_equals "|0" "$(resolve ai update)" "a planned verb never falls through to the old route"

test_start "every_alias_target_runs"
unresolved=""
while IFS='|' read -r rec name kind target _; do
  [[ "$rec" == alias && "$kind" != removed ]] || continue
  [[ "$target" == help || "$target" == version ]] && continue # built-ins
  # shellcheck disable=SC2086 # the target is words
  got="$(resolve $target)"
  [[ -n "${got%%|*}" ]] || unresolved="$unresolved $name"
done <"$TABLE"
assert_equals "" "$unresolved" "each deprecated name and shortcut points at a command that runs"

test_start "old_invocations_get_their_new_spelling"
spell() { "$BASH_BIN" -c "source '$WORK/names.sh'; _dot_longest leg \"\$@\"; echo \"\$_BEST\"" _ "$@"; }
assert_equals "secret set" "$(spell secrets set KEY)" "the subcommand picks the spelling"
assert_equals "system update" "$(spell upgrade --yes)" "a renamed route"
assert_equals "ai start claude" "$(spell cl)" "an alias with arguments gets its full spelling"

test_start "version_compare"
ge() { "$BASH_BIN" -c "source '$WORK/names.sh'; _dot_version_ge \"\$1\" \"\$2\"" _ "$1" "$2"; }
assert_true "ge 0.2.538 0.2.538" "equal"
assert_true "ge 0.2.540 0.2.538" "later patch"
assert_true "ge 0.3.0 0.2.999" "later minor"
assert_false "ge 0.2.537 0.2.538" "earlier patch"
assert_false "ge 0.2.99 0.10.0" "numeric, not lexical"

test_start "unknown_and_removed_names_exit_127"
rc=0
dot no-such-command-n03 || rc=$?
assert_equals "127" "$rc" "unknown command (N10)"
assert_file_contains "$WORK/err" "Unknown command: no-such-command-n03" "says so on stderr"
rc=0
DOT_BIN="$WORK/src/bin/dot" dot frob || rc=$?
assert_equals "127" "$rc" "removed name"
assert_file_contains "$WORK/err" "'dot frob' was removed; use 'dot doctor'" "with its replacement"
rc=0
dot system schedule set weekly || rc=$?
assert_equals "127" "$rc" "planned command"
assert_file_contains "$WORK/err" "'dot system schedule set' is not available yet" "names the spelling"
rc=0
dot 'doc.*' || rc=$?
assert_equals "127" "$rc" "a pattern in a name is not a regex"

test_start "planned_command_never_reaches_the_old_route"
# `dot ai <word>` sends <word> to a model as a prompt: a planned verb must
# stop at 127, not fall through to the domain's own route.
rc=0
dot ai update || rc=$?
assert_equals "127" "$rc" "planned verb of a domain with its own route"
assert_file_contains "$WORK/err" "'dot ai update' is not available yet" "names the spelling"

test_start "domain_alone_lists_its_commands"
rc=0
dot system || rc=$?
assert_equals "0" "$rc" "read-only, exits 0 (N5)"
assert_file_contains "$WORK/out" "dot system update" "lists a built command"
assert_file_contains "$WORK/out" "(planned)" "marks a planned one"

test_start "deprecated_name_warns_once_per_session"
rm -rf "$WORK/home/.local/state/dot"
dot search zz-no-match || true
assert_file_contains "$WORK/err" "'dot search' is deprecated; use 'dot help'" "first use warns"
assert_file_contains "$WORK/err" "stops working in 0.2.538" "with the release it stops in"
dot search zz-no-match || true
assert_output_not_contains "deprecated" "cat '$WORK/err'" "second use in the same session is quiet"

test_start "markers_of_old_sessions_are_pruned"
marks="$WORK/home/.local/state/dot/cli/deprecated"
rm -rf "$marks"
mkdir -p "$marks"
printf 'search\n' >"$marks/999999"
touch -t 202001010000 "$marks/999999"
dot search zz-no-match || true
assert_file_not_exists "$marks/999999" "a marker from an earlier day is removed"
assert_file_contains "$WORK/err" "deprecated" "and this session is warned"

test_start "deprecated_name_expires_at_its_release"
rc=0
DOT_BIN="$WORK/src/bin/dot" dot frob-old || rc=$?
assert_equals "127" "$rc" "past its release a deprecated name exits 127"
assert_file_contains "$WORK/err" "'dot frob-old' was removed; use 'dot doctor'" "with the hint"

test_start "gnu_version_and_verbose_flags"
dot --version
long="$(cat "$WORK/out")"
dot -V
assert_equals "$long" "$(cat "$WORK/out")" "-V prints the version (N9)"
dot -v
assert_equals "$long" "$(cat "$WORK/out")" "-v alone still prints it in this release"
assert_file_contains "$WORK/err" "use 'dot -V'" "with a warning"
rc=0
dot -v no-such-command-n03 || rc=$?
assert_equals "127" "$rc" "-v before a command passes on to it"
later="$("$BASH_BIN" -c "source '$WORK/names.sh'; VERSION=0.2.538; show_help() { echo overview; }; _dot_names -v" 2>&1)"
assert_equals "overview" "$later" "after the window -v alone is --verbose with no command: the overview"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
