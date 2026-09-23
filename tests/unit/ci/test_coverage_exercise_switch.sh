#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# DOTFILES_COV_EXERCISE=0 must turn every cov_exercise_* helper into a
# no-op, so the behavioural-only coverage lane measures what tests assert
# on and nothing else. Each helper is given a script that records every
# invocation; with the switch off it is never invoked, with the default it
# is.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cov-switch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cat >"$WORK/probe.sh" <<PROBE
#!/usr/bin/env bash
echo "run \$*" >>"$WORK/calls"
probe_fn() { echo "fn" >>"$WORK/calls"; }
PROBE
chmod +x "$WORK/probe.sh"

# Run one helper in a fresh bash with the switch set as given.
helper() {
  local switch="$1" fn="$2"
  rm -f "$WORK/calls"
  DOTFILES_COV_EXERCISE="$switch" HOME="$WORK/home" bash -c '
    source "$1/tests/framework/coverage_helpers.sh"
    "$2" "$3"' _ "$REPO_ROOT" "$fn" "$WORK/probe.sh" >/dev/null 2>&1 || true
  [[ -f "$WORK/calls" ]] && wc -l <"$WORK/calls" | tr -d ' ' || echo 0
}

for fn in cov_exercise_script cov_exercise_script_help_only cov_exercise_functions_file; do
  test_start "${fn}_is_a_no_op_when_switched_off"
  assert_equals "0" "$(helper 0 "$fn")" "probe never invoked with DOTFILES_COV_EXERCISE=0"
  test_start "${fn}_runs_the_probe_by_default"
  assert_not_equals "0" "$(helper 1 "$fn")" "probe invoked with the default"
done

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
