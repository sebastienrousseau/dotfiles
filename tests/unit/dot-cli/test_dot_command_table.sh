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

TABLE="$REPO_ROOT/lib/dot/data/commands.txt"
BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-names.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# The dispatcher pinned to 0.2.537, inside the deprecation window of the
# names that stop working in 0.2.538, so these cases do not depend on the
# release being tested.
source "$SCRIPT_DIR/../../framework/pinned_dot.sh"
DOT_CLI="$(pinned_dot "$WORK/pinned" 0.2.537)"

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
cp "$REPO_ROOT/bin/dot" "$WORK/src/bin/dot"
pin_names "$WORK/src/lib/dot" 0.2.537 # inside the window, as above
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
assert_equals "agent delegate run|3" "$(resolve agent delegate run test-runner true)" "delegate run keeps the name and command"
assert_equals "agent delegate list|2" "$(resolve agent delegate)" "a delegate object alone lists them"

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
assert_equals "scorecard|2" "$(resolve doctor score --json)" "an object and a flag runs its default verb too"
assert_equals "env|1" "$(resolve tool)" "a domain alone runs its own route first"
assert_equals "ai|1" "$(resolve ai tools)" "an old subcommand goes to the domain's own route"
assert_equals "ai chat|2" "$(resolve ai start claude)" "ai start <agent> opens an interactive session, not a one-shot prompt"
assert_equals "ai run|2" "$(resolve ai run claude --pattern p q)" "ai run <agent> is the one-shot, with its flags"

test_start "declared_but_not_built_resolves_to_nothing"
assert_equals "|0" "$(resolve secret key list)" "a planned command is not run"
assert_equals "|0" "$(resolve secret)" "a domain whose default is planned"
assert_equals "system schedule set|3" "$(resolve system schedule set weekly)" "a built command runs its route, its value left as an argument"
assert_equals "mode doctor|2" "$(resolve agent check)" "a domain with its own route runs the default verb's route only when bare has none"
assert_equals "|0" "$(resolve ai gateway show)" "a planned verb never falls through to the old route"

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
assert_equals "" "$(spell cl)" "a name with no route of its own falls back to its alias target"

test_start "record_keys_are_words_only"
rec() { "$BASH_BIN" -c "source '$WORK/names.sh'; _dot_record \"\$1\" \"\$2\"" _ "$1" "$2"; }
assert_true "rec cmd 'secret set'" "a known key"
assert_false "rec cmd 'secret set|secrets set'" "a | never splits the lookup into alternatives"

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
dot secret key list || rc=$?
assert_equals "127" "$rc" "planned command"
assert_file_contains "$WORK/err" "'dot secret key list' is not available yet" "names the spelling"
rc=0
dot 'doc.*' || rc=$?
assert_equals "127" "$rc" "a pattern in a name is not a regex"

test_start "planned_command_never_reaches_the_old_route"
# `dot ai <word>` sends <word> to a model as a prompt: a planned verb must
# stop at 127, not fall through to the domain's own route.
rc=0
dot ai gateway show || rc=$?
assert_equals "127" "$rc" "planned verb of a domain with its own route"
assert_file_contains "$WORK/err" "'dot ai gateway show' is not available yet" "names the spelling"

test_start "domain_alone_lists_its_commands"
rc=0
dot secret || rc=$?
assert_equals "0" "$rc" "read-only, exits 0 (N5)"
assert_equals "dot secret · secrets, keys and SSH certificates" "$(head -1 "$WORK/out")" "its own header"
assert_output_not_contains "dot config ·" "cat '$WORK/out'" "and no other domain's"
assert_equals "" "$(grep 'dot secret list ' "$WORK/out" | grep -F '(planned)')" "a built command is not marked planned"
assert_not_empty "$(grep 'dot secret status ' "$WORK/out" | grep -F '(planned)')" "a planned one is"

test_start "help_topics_still_resolve"
rc=0
dot help sync || rc=$?
assert_equals "0" "$rc" "dot help <command> is not taken for a planned spelling"
assert_file_contains "$WORK/out" "dot sync" "and shows that command"
rc=0
dot help zz-no-such-topic || rc=$?
assert_equals "1" "$rc" "an unknown topic that matches nothing fails"

test_start "a_typo_after_an_object_stops"
# `dot ai <words>` sends the words to a model: a word that is not a verb of
# an object must stop at 127, not fall through to the domain's own route.
rc=0
dot ai pattern zzz || rc=$?
assert_equals "127" "$rc" "not a verb of ai pattern"
assert_file_contains "$WORK/err" "'dot ai pattern zzz' is not a command; run 'dot help ai pattern'" "names it and the help"
rc=0
dot ai pattern list >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "a real verb still runs"
dot ai pattern S3cret-x || true
assert_output_not_contains "S3cret" "cat '$WORK/err'" "a value-like word is left out of that error"

test_start "arguments_are_not_echoed"
dot system schedule S3cret-x || true
assert_output_not_contains "S3cret" "cat '$WORK/err'" "a value-like word is left out of the error"

test_start "deprecated_name_warns_once_per_session"
rm -rf "$WORK/home/.local/state/dot"
dot search zz-no-match || true
assert_file_contains "$WORK/err" "'dot search' is deprecated; use 'dot help'" "first use warns"
assert_file_contains "$WORK/err" "stops working in 0.2.538" "with the release it stops in"
assert_file_contains "$WORK/out" "No commands matching" "and the command still runs"
dot search zz-no-match || true
assert_output_not_contains "deprecated" "cat '$WORK/err'" "second use in the same session is quiet"
assert_file_contains "$WORK/out" "No commands matching" "and still runs"
rm -rf "$WORK/home/.local/state/dot"
rc=0
dot search --help || rc=$?
assert_equals "0" "$rc" "help on a deprecated name still shows help"
assert_file_contains "$WORK/err" "deprecated" "help warns too"
assert_dir_not_exists "$WORK/home/.local/state/dot" "but records nothing: help writes no file"

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

test_start "without_its_library_dot_still_answers"
# A dispatcher with no lib/ beside it and no source dir to find.
mkdir -p "$WORK/bare/bin" "$WORK/bare/home"
cp "$DOT_CLI" "$WORK/bare/bin/dot"
bare() { (cd "$WORK/bare" && HOME="$WORK/bare/home" NO_COLOR=1 "$BASH_BIN" bin/dot "$@" >"$WORK/out" 2>"$WORK/err" </dev/null); }
rc=0
bare || rc=$?
assert_equals "0" "$rc" "no command shows the overview"
assert_file_contains "$WORK/out" "Usage: dot <domain> [object] <verb>" "and the usage is printed"
rc=0
bare no-such-command-n03 || rc=$?
assert_equals "127" "$rc" "an unknown command still exits 127"

test_start "a_missing_module_fails_cleanly"
rc=0
DOT_BIN="$WORK/src/bin/dot" dot manual || rc=$?
assert_equals "1" "$rc" "the source tree has no scripts/: the route's module is missing"
assert_file_contains "$WORK/err" "manual.sh not found" "says which"

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
