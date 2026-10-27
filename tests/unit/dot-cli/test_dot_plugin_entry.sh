#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# A bundled plugin with an entry (ADR-020 N2, P2.1) runs its own commands:
# bin/dot resolves `dot <domain> ...` to the route @<domain> and hands the
# words after the domain to plugins/<domain>/dot-<domain>. Words its table
# does not take reach the entry too, as a domain's legacy route took them;
# planned commands, non-verbs after an object and --help never do.
# theme is the first plugin with an entry. The scripts it runs are recorded
# by a bash shim instead of run.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-entry.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"

cat >"$WORK/bin/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  */scripts/theme/*|*/scripts/fonts/*)
    printf 'ran %s %s\n' "\${1##*/scripts/}" "\${*:2}"
    exit "\${DISPATCH_RC:-0}" ;;
esac
exec "$REAL_BASH" "\$@"
EOF
chmod +x "$WORK/bin/bash"

# dot <args...> — run a dispatcher (DOT_BIN, else the repo's) in a sandboxed
# HOME with the shim on PATH; stdout to out, stderr to err; sets RC.
dot() {
  RC=0
  (cd "$WORK" && HOME="$WORK/home" XDG_STATE_HOME="$WORK/home/.local/state" \
    XDG_CACHE_HOME="$WORK/home/.cache" XDG_CONFIG_HOME="$WORK/home/.config" \
    DOTFILES_SHOW_LOGO=0 NO_COLOR=1 TERM=dumb PATH="$WORK/bin:/usr/bin:/bin" \
    "$REAL_BASH" "${DOT_BIN:-$REPO_ROOT/bin/dot}" "$@") \
    >"$WORK/out" 2>"$WORK/err" </dev/null || RC=$?
}

# ran <args...> — the script line `dot <args>` ran, or empty.
ran() {
  dot "$@"
  grep '^ran ' "$WORK/out" | head -1
}

# resolve <words...> — "<route words>|<words replaced>" from the resolver.
resolve() {
  "$REAL_BASH" -c '_DOT_SRC="$1" VERSION=0; shift; source "$_DOT_SRC/lib/dot/names.sh"
    _dot_resolve "$@"; printf "%s|%s\n" "$_RUN" "$_RUN_USED"' _ "$REPO_ROOT" "$@"
}

test_start "entry_routes_come_from_the_manifest"
assert_equals "@theme|1" "$(resolve theme)" "the bare domain runs the entry"
assert_equals "@theme show|2" "$(resolve theme show)" "a built verb runs the entry with its spelling"
assert_equals "@theme wallpaper set|3" "$(resolve theme wallpaper set rotate)" "domain, object and verb"
assert_equals "|0" "$(resolve theme font list)" "a planned command has no route"

test_start "declared_spellings_run_the_entry"
assert_equals "ran theme/switch.sh current" "$(ran theme show)" "dot theme show is the current theme"
assert_equals "ran theme/switch.sh list" "$(ran theme list)" "dot theme list"
assert_equals "ran theme/switch.sh set dracula" "$(ran theme set dracula)" "dot theme set keeps its argument"
assert_equals "ran theme/wallpaper-rotate.sh --next" "$(ran theme wallpaper set rotate --next)" "dot theme wallpaper set rotate"
assert_equals "ran fonts/patch-fonts.sh My.ttf" "$(ran theme font install patch My.ttf)" "dot theme font install patch"

test_start "other_words_reach_the_entry"
assert_equals "ran theme/switch.sh " "$(ran theme)" "dot theme alone opens the picker"
assert_equals "ran theme/switch.sh toggle" "$(ran theme toggle)" "an undeclared word goes to the switcher"
assert_equals "ran theme/switch.sh dracula" "$(ran theme dracula)" "a theme name switches to it"
assert_equals "ran theme/switch.sh font" "$(ran theme font)" "an object with no built default goes to the entry"

test_start "the_entry_status_is_the_command_status"
DISPATCH_RC=3 dot theme set nope
assert_equals "3" "$RC" "the script's exit status comes back through bin/dot"

test_start "planned_and_unknown_words_never_reach_the_entry"
dot theme font list
assert_equals "127" "$RC" "a planned command exits 127 (N10)"
assert_contains "not available yet" "$(cat "$WORK/err")" "and says so"
assert_equals "" "$(grep '^ran ' "$WORK/out")" "the entry did not run"
dot theme font bogus
assert_equals "127" "$RC" "a word that is not a verb of the object exits 127"
assert_equals "" "$(grep '^ran ' "$WORK/out")" "the entry did not run"

test_start "help_never_reaches_the_entry"
for words in "theme --help" "theme toggle --help" "theme wallpaper set -h" "theme font install --help"; do
  # shellcheck disable=SC2086 # words
  dot $words
  assert_equals "0" "$RC" "dot $words exits 0"
  assert_equals "" "$(grep '^ran ' "$WORK/out")" "dot $words runs nothing"
done

# A source tree whose theme plugin has lost its entry: bin/dot finds its
# lib/ beside it and fails rather than fall back to another route.
test_start "a_missing_entry_fails"
mkdir -p "$WORK/src/bin" "$WORK/src/plugins/theme"
cp "$REPO_ROOT/bin/dot" "$WORK/src/bin/dot"
ln -s "$REPO_ROOT/lib" "$WORK/src/lib"
ln -s "$REPO_ROOT/scripts" "$WORK/src/scripts"
DOT_BIN="$WORK/src/bin/dot" dot theme list
assert_equals "1" "$RC" "a missing entry exits 1"
assert_contains "dot-theme not found" "$(cat "$WORK/err")" "and names it"
assert_equals "" "$(grep '^ran ' "$WORK/out")" "nothing else ran"

test_summary
