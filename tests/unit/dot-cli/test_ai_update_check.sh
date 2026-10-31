#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# `dot ai update --check` lists the AI CLIs whose [ai_tools] pin has a newer
# release and changes nothing; `dot system update` reads its pin report from
# it instead of loading the ai plugin's installer (P2.2 edge 5b). The updater
# is a sandbox stand-in that only records it ran: the real one upgrades brew,
# npm globals and the native agents.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-update-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/src/defaults/dot_local/bin"
cat >"$WORK/src/defaults/dot_local/bin/executable_ai-update" <<EOF
echo "updater ran: \$*" >>"$WORK/updater.log"
EOF
cat >"$WORK/bin/mise" <<'EOF'
#!/bin/sh
[ "$1" = latest ] || exit 0
case "$2" in
  npm:@openai/codex) echo 9.9.9 ;;
  *) echo 1.0.0 ;;
esac
EOF
chmod +x "$WORK/bin/mise"
cat >"$WORK/pins.toml" <<'TOML'
[ai_tools]
"npm:@openai/codex" = "0.162.1"
"kiro-cli" = "1.0.0"
TOML

# update ARGS...: cmd_ai_update in the sandbox; stdout in OUT, status in RC.
update() {
  rm -f "$WORK/updater.log"
  RC=0
  OUT="$(PATH="$WORK/bin:/usr/bin:/bin" bash -c '
    set -euo pipefail
    source "$1/lib/dot/utils.sh"
    source "$1/lib/dot/ai-commands.sh"
    src="$2/src"
    resolve_source_dir() { printf "%s\n" "$src"; }
    _AI_PINS_FILE="$2/pins.toml"
    shift 2
    cmd_ai_update "$@"' _ "$REPO_ROOT" "$WORK" "$@" 2>&1)" || RC=$?
}

test_start "check_lists_the_newer_releases"
update --check
assert_equals "0" "$RC" "the check succeeds"
assert_equals "npm:@openai/codex 0.162.1 -> 9.9.9" "$OUT" \
  "one line per pin behind its latest release, nothing else on stdout"
assert_file_not_exists "$WORK/updater.log" "and the updater does not run"

test_start "check_with_every_pin_current_prints_nothing"
printf '[ai_tools]\n"kiro-cli" = "1.0.0"\n' >"$WORK/pins.toml"
update --check
assert_equals "0" "$RC" "a current set of pins is not an error"
assert_equals "" "$OUT" "and prints nothing"
assert_file_not_exists "$WORK/updater.log" "without running the updater"

test_start "check_takes_no_other_word"
update --check codex
assert_equals "2" "$RC" "a word after --check is a usage error"
assert_file_not_exists "$WORK/updater.log" "and nothing is updated"

test_start "update_without_check_runs_the_updater"
update --yes
assert_equals "updater ran: --yes" "$(cat "$WORK/updater.log" 2>/dev/null)" \
  "plain update still hands its words to the updater"

# The pin step of `dot system update`: upgrade.sh asks `dot ai update --check`
# through the dot it runs (DOT_SYSTEM_DOT), so it loads no ai plugin code.
cat >"$WORK/bin/fake-dot" <<EOF
#!/bin/sh
echo "\$*" >>"$WORK/dot.log"
[ "\$*" = "ai update --check" ] && echo "npm:@openai/codex 0.162.1 -> 9.9.9"
EOF
chmod +x "$WORK/bin/fake-dot"

# pins: _dot_upgrade_pins into $WORK/pins.list; its line in OUT, status in RC.
pins() {
  rm -f "$WORK/dot.log" "$WORK/pins.list"
  RC=0
  OUT="$(DOT_SYSTEM_DOT="$1" bash -c '
    set -euo pipefail
    source "$2/lib/dot/utils.sh"
    source "$2/lib/dot/upgrade.sh"
    declare -F ai_pin_bumps >/dev/null && echo "installer loaded"
    _dot_upgrade_pins "$3/pins.list"' _ "$1" "$REPO_ROOT" "$WORK" 2>&1)" || RC=$?
}

test_start "update_pin_step_asks_the_ai_plugin"
pins "$WORK/bin/fake-dot"
assert_equals "0" "$RC" "the pin step succeeds"
assert_equals "1 newer release(s), listed below" "$OUT" \
  "counts the bumps, without loading the AI installer"
assert_equals "ai update --check" "$(cat "$WORK/dot.log" 2>/dev/null)" "by running dot ai update --check"
assert_equals "npm:@openai/codex 0.162.1 -> 9.9.9" "$(cat "$WORK/pins.list" 2>/dev/null)" \
  "and keeps its lines for the report"

test_start "update_pin_step_fails_when_the_check_does"
pins /bin/false
assert_not_equals "0" "$RC" "a failed check fails the step instead of reporting every pin current"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
