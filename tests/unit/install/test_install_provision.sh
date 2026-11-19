#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# run_provision (install/lib/provision.sh) against stub provisioning
# scripts: it runs only scripts whose content changed since their last
# successful run (or every script with --all), records each script's exit
# status, and fails at the end naming every script that failed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-provision.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

SRC="$WORK/src"
PROV="$SRC/install/provision"
RUNS="$WORK/runs"
export XDG_STATE_HOME="$WORK/state"
STATE="$XDG_STATE_HOME/dot/provision"
mkdir -p "$PROV" "$WORK/bin"

# A chezmoi stub whose execute-template renders by substituting {{ .x }}.
printf '#!/usr/bin/env bash\n[[ "$1" == execute-template ]] || exit 2\nsed "s/{{ .x }}/rendered/"\n' >"$WORK/bin/chezmoi"
chmod +x "$WORK/bin/chezmoi"
export PATH="$WORK/bin:$PATH"

# script <file> <body>: a provisioning script that logs its name to $RUNS,
# then runs <body>.
script() {
  printf '#!/usr/bin/env bash\necho "%s" >>"%s"\n%s\n' "${1%%.*}" "$RUNS" "$2" >"$PROV/$1"
}

# provision [args]: run_provision in a subshell; output in $OUT, rc in $RC.
provision() {
  : >"$RUNS"
  OUT="$(source "$REPO_ROOT/install/lib/provision.sh" && run_provision "$SRC" "$@" 2>&1 </dev/null)"
  RC=$?
}

ran() { grep -qx "$1" "$RUNS"; }

script run_onchange_10-ok.sh 'exit 0'
script run_onchange_20-fails.sh 'exit 3'
script run_onchange_30-changes.sh 'exit 0'
script run_once_install_shell.sh 'exit 0'

test_start "first_run_runs_every_script_and_fails_on_a_failure"
provision
assert_not_equals "0" "$RC" "a failing script makes run_provision fail"
assert_true 'ran run_onchange_10-ok' "the passing script ran"
assert_true 'ran run_onchange_20-fails' "the failing script ran"
assert_true 'ran run_onchange_30-changes' "the script after the failure still ran"
assert_equals "run_once_install_shell" "$(head -n 1 "$RUNS")" "run_once_install_* scripts run first"
assert_contains "run_onchange_20-fails.sh" "$OUT" "the failed script is named"
assert_contains "exit 3" "$OUT" "with its exit status"
assert_file_contains "$STATE/status" "run_onchange_20-fails.sh 3" "the failure's exit status is recorded"
assert_file_contains "$STATE/status" "run_onchange_10-ok.sh 0" "a success's exit status is recorded"

test_start "unchanged_scripts_are_skipped_and_failures_retried"
provision
assert_not_equals "0" "$RC" "the still-failing script fails the run again"
assert_false 'ran run_onchange_10-ok' "an unchanged script that passed is skipped"
assert_true 'ran run_onchange_20-fails' "a script that failed last time runs again"
assert_file_contains "$STATE/status" "run_onchange_10-ok.sh skipped" "a skip is recorded"

test_start "a_changed_script_runs_again"
script run_onchange_20-fails.sh 'exit 0'
script run_onchange_30-changes.sh 'echo v2 >/dev/null'
provision
assert_equals "0" "$RC" "every script passes"
assert_true 'ran run_onchange_30-changes' "the changed script ran"
assert_false 'ran run_onchange_10-ok' "the unchanged script did not"
provision
assert_equals "" "$(cat "$RUNS")" "nothing runs when nothing changed"
assert_equals "0" "$RC" "and the run succeeds"

test_start "all_runs_every_script"
provision --all
assert_equals "0" "$RC" "--all succeeds"
assert_true 'ran run_onchange_10-ok' "--all runs an unchanged script"
assert_true 'ran run_onchange_30-changes' "and every other one"

test_start "a_template_runs_rendered_and_reruns_when_its_rendering_changes"
printf '#!/usr/bin/env bash\necho "{{ .x }}" >>"%s"\n' "$RUNS" >"$PROV/run_onchange_40-tmpl.sh.tmpl"
provision
assert_equals "rendered" "$(cat "$RUNS")" "the rendered template ran"
provision
assert_equals "" "$(cat "$RUNS")" "an unchanged template is skipped"
printf '#!/usr/bin/env bash\nsed "s/{{ .x }}/other/"\n' >"$WORK/bin/chezmoi"
provision
assert_equals "other" "$(cat "$RUNS")" "a template whose rendering changed runs again"

test_start "a_template_that_fails_to_render_is_a_failure"
printf '#!/usr/bin/env bash\nexit 1\n' >"$WORK/bin/chezmoi"
provision --all
assert_not_equals "0" "$RC" "a render failure fails the run"
assert_contains "run_onchange_40-tmpl.sh.tmpl could not be rendered" "$OUT" "says the template did not render"
assert_contains "run_onchange_40-tmpl.sh.tmpl (exit 1)" "$OUT" "and names it among the failures"
assert_file_contains "$STATE/status" "run_onchange_40-tmpl.sh.tmpl 1" "a render failure is recorded as exit 1"

test_start "no_provision_directory_is_a_no_op"
OUT="$(source "$REPO_ROOT/install/lib/provision.sh" && run_provision "$WORK/empty" 2>&1)"
assert_equals "0" "$?" "a source without install/provision succeeds"

test_summary
