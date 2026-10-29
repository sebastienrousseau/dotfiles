#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Plugin lifecycle hooks (P2.2): lib/dot/hooks.sh runs each plugin's hook
# for an event from the command table, in domain order. Each case builds a
# tree whose route fragments declare hooks that log what they saw, and runs
# dot_hooks_run in a child bash against it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hooks.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/src"
LOG="$WORK/log"

# plugin DOMAIN RECORD...: a plugin whose fragment holds the records.
plugin() {
  local d="$SRC/plugins/$1"
  shift
  mkdir -p "$d/libexec/hooks"
  printf 'dom|%s|status||a plugin\n' "${d##*/}" >"$d/commands.txt"
  printf '%s\n' "$@" >>"$d/commands.txt"
}

# hook_script DOMAIN NAME [RC]: a hook that logs its domain, event and
# interactivity, then exits RC.
hook_script() {
  cat >"$SRC/plugins/$1/libexec/hooks/$2" <<EOF
echo "$1 \$DOT_HOOK_EVENT \${DOT_HOOK_INTERACTIVE:-unset}" >>"$LOG"
exit ${3:-0}
EOF
}

mkdir -p "$SRC/lib/dot/data"
cp "$REPO_ROOT/lib/dot/table-merge.awk" "$SRC/lib/dot/"
printf 'grp|g|Group|alpha beta gamma bad|\n' >"$SRC/lib/dot/data/groups.txt"
plugin alpha 'hook|on-apply|alpha|libexec/hooks/apply.sh|Alpha checks' 'hook|on-update|alpha|libexec/hooks/update.sh|Alpha update'
plugin beta 'hook|on-apply|beta|libexec/hooks/apply.sh|Beta checks'
plugin gamma 'hook|on-apply|gamma|libexec/hooks/apply.sh|Gamma checks'
plugin bad 'hook|on-apply|Bad|libexec/hooks/apply.sh|uppercase domain' \
  'hook|on-apply|bad|scripts/apply.sh|outside libexec' \
  'hook|on-apply|bad|libexec/../../../evil.sh|climbs out' \
  'hook|on-apply|bad|libexec/hooks/missing.sh|no such script'
hook_script alpha apply.sh
hook_script alpha update.sh
hook_script beta apply.sh 3
hook_script gamma apply.sh
mkdir -p "$SRC/plugins/bad/scripts" "$SRC/plugins/Bad/libexec/hooks"
printf 'echo "bad ran" >>"%s"\n' "$LOG" | tee "$SRC/plugins/bad/scripts/apply.sh" "$SRC/plugins/bad/libexec/hooks/apply.sh" "$SRC/plugins/Bad/libexec/hooks/apply.sh" "$SRC/evil.sh" >/dev/null

# run_hooks EVENT [VAR=value...]: dot_hooks_run EVENT in a child bash; OUT, RC.
run_hooks() {
  local event="$1"
  shift
  : >"$LOG"
  RC=0
  OUT="$(env "$@" XDG_CACHE_HOME="$WORK/cache" NO_COLOR=1 bash -c '
    set -euo pipefail
    _DOT_SRC="$1"
    source "$2/lib/dot/ui.sh"
    source "$2/lib/dot/names.sh"
    source "$2/lib/dot/hooks.sh"
    dot_hooks_run "$3"
  ' _ "$SRC" "$REPO_ROOT" "$event" 2>&1)" || RC=$?
}

test_start "on_apply_runs_each_plugins_hook_in_domain_order"
run_hooks on-apply DOT_HOOK_INTERACTIVE=1
assert_equals "alpha on-apply 1|beta on-apply 1|gamma on-apply 1" "$(paste -sd'|' "$LOG")" \
  "alpha, beta, gamma: each sees the event and the interactivity"
assert_contains "Alpha checks" "$OUT" "under its summary as a header"

test_start "a_failing_hook_is_a_warning"
assert_contains "beta on-apply hook failed (continuing)" "$(printf '%s' "$OUT" | tr -s ' ')" "beta's exit 3 is reported"
assert_equals "0" "$RC" "and the run, and the hooks after it, carry on"

test_start "only_the_events_hooks_run"
run_hooks on-update
assert_equals "alpha on-update unset" "$(cat "$LOG")" "on-update runs alpha's update hook alone"

test_start "records_of_the_wrong_shape_are_skipped"
run_hooks on-apply
assert_equals "0" "$(grep -c 'bad ran' "$LOG")" "no bad record runs a script"
assert_equals "1" "$(tr -s " " <<<"$OUT" | grep -c "bad on-apply hook failed")" "a declared script that is missing is reported, once"
assert_equals "0" "$RC" "and neither is an error"

test_start "hooks_never_write_the_route_cache"
assert_file_not_exists "$WORK/cache/dot/cli/commands.txt" "the table is read, not cached"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
