#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Branch coverage for scripts/qa/validate-examples.sh.
#
# The script derives EXAMPLES_DIR from its own location, so running it in the
# checkout means running every real example — minutes of work, and no way to
# stage a failing or hanging one. Instead each case builds a throwaway project
# with the script SYMLINKED into it: `dirname "${BASH_SOURCE[0]}"` does not
# follow the link, so REPO_ROOT becomes the fixture while the xtrace records
# still name the real file.
#
# The timeout-resolution arms are driven with stub binaries on an explicit
# PATH rather than with whatever the host happens to ship, so all three
# (timeout / gtimeout / neither) are exercised on every platform.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

VE_FILE="$REPO_ROOT/scripts/qa/validate-examples.sh"

WORK="$(mktemp -d -t vex.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

# A PATH with only the handful of binaries validate-examples.sh actually
# shells out to, so `command -v timeout` answers what the case wants rather
# than what the host has installed.
BASEBIN="$WORK/basebin"
mkdir -p "$BASEBIN"
for tool in basename dirname cat find sort env bash; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$BASEBIN/$tool"
done

# ve_project <name> — a fixture project holding the symlinked script and an
# empty examples/ directory. Prints its path.
ve_project() {
  local d="$WORK/$1"
  rm -rf "$d"
  mkdir -p "$d/scripts/qa" "$d/examples"
  ln -s "$VE_FILE" "$d/scripts/qa/validate-examples.sh"
  printf '%s\n' "$d"
}

# ve_example <dir> <name> <exit-code>
ve_example() {
  printf '#!/usr/bin/env bash\necho "example %s"\nexit %s\n' "$2" "$3" \
    >"$1/examples/$2.sh"
}

# ve_stub <dir> <name> <exit-code> — a stub that swallows its arguments.
ve_stub() {
  printf '#!/usr/bin/env bash\nexit %s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

VE_OUT=""
VE_RC=0
# ve_run <project> [extra-PATH-dir] [args...]
#
# The script is invoked from inside the project by its RELATIVE path. The
# coverage aggregator resolves a relative trace source against the repo root,
# which is what attributes these runs to the real scripts/qa file; an absolute
# fixture path would only resolve while the fixture still exists, and the EXIT
# trap deletes it well before aggregation.
ve_run() {
  local proj="$1" extra="${2:-}"
  shift 2 || shift $#
  local path="$BASEBIN"
  [[ -n "$extra" ]] && path="$extra:$BASEBIN"
  VE_RC=0
  VE_OUT="$(
    cd "$proj" &&
      PATH="$path" EXAMPLE_TIMEOUT="${VE_TIMEOUT:-60}" \
        "${BASH:-bash}" scripts/qa/validate-examples.sh "$@" 2>&1
  )" || VE_RC=$?
}

# ── 1. Usage surface ───────────────────────────────────────────────────────
proj="$(ve_project usage)"

test_start "validate_examples_help_exits_zero"
ve_run "$proj" "" --help
assert_equals "0" "$VE_RC" "--help should exit 0"
assert_contains "Usage:" "$VE_OUT" "--help should print the usage block"

test_start "validate_examples_short_help"
ve_run "$proj" "" -h
assert_equals "0" "$VE_RC" "-h should behave like --help"

test_start "validate_examples_rejects_unknown_option"
ve_run "$proj" "" --not-a-flag
assert_equals "2" "$VE_RC" "an unknown option should exit 2"
assert_contains "Unknown option" "$VE_OUT" "the rejection should name the option"

# ── 2. Nothing to run ──────────────────────────────────────────────────────
test_start "validate_examples_requires_an_examples_directory"
proj="$(ve_project no_dir)"
rmdir "$proj/examples"
ve_run "$proj"
assert_equals "1" "$VE_RC" "a missing examples/ should exit 1"
assert_contains "No examples directory" "$VE_OUT" "the failure should say so"

test_start "validate_examples_requires_at_least_one_example"
proj="$(ve_project empty_dir)"
ve_run "$proj"
assert_equals "1" "$VE_RC" "an empty examples/ should exit 1"
assert_contains "No executable examples" "$VE_OUT" "the failure should say so"

# ── 3. Passing and failing examples ────────────────────────────────────────
test_start "validate_examples_passes_a_clean_suite"
proj="$(ve_project clean)"
ve_example "$proj" alpha 0
ve_example "$proj" beta 0
ve_run "$proj"
assert_equals "0" "$VE_RC" "two passing examples should exit 0"
assert_contains "Examples passed." "$VE_OUT" "the clean verdict should be printed"
assert_contains "Running example: alpha.sh" "$VE_OUT" "each example should be announced"

test_start "validate_examples_reports_a_failing_example"
proj="$(ve_project failing)"
ve_example "$proj" alpha 0
ve_example "$proj" broken 3
ve_run "$proj"
assert_equals "1" "$VE_RC" "a failing example should make the run exit 1"
assert_contains "broken.sh exited 3" "$VE_OUT" \
  "the failure should name the example and its status"
assert_contains "1 example(s) failed." "$VE_OUT" "the tally should be printed"

# ── 4. Timeout resolution, one arm per case ────────────────────────────────
#
# 4a. `timeout` present. The stub reports 124 without running anything, which
#     is exactly what a real expiry looks like to this script.
test_start "validate_examples_reports_a_timed_out_example"
proj="$(ve_project timed_out)"
ve_example "$proj" slow 0
stubs="$WORK/stubs_timeout"
mkdir -p "$stubs"
ve_stub "$stubs" timeout 124
VE_TIMEOUT=1 ve_run "$proj" "$stubs"
assert_equals "1" "$VE_RC" "a timed-out example should make the run exit 1"
assert_contains "exceeded the 1s timeout" "$VE_OUT" \
  "the timeout failure should name the budget"

# 4b. No `timeout`, but `gtimeout` — the macOS-with-coreutils shape.
test_start "validate_examples_falls_back_to_gtimeout"
proj="$(ve_project gtimeout)"
ve_example "$proj" alpha 0
stubs="$WORK/stubs_gtimeout"
mkdir -p "$stubs"
ve_stub "$stubs" gtimeout 0
VE_TIMEOUT=30 ve_run "$proj" "$stubs"
assert_equals "0" "$VE_RC" "gtimeout should be accepted as the bounding wrapper"

# 4c. Neither wrapper available: warn, then run unbounded.
test_start "validate_examples_warns_when_unbounded"
proj="$(ve_project unbounded)"
ve_example "$proj" alpha 0
VE_TIMEOUT=30 ve_run "$proj"
assert_equals "0" "$VE_RC" "a missing timeout binary should not fail the run"
assert_contains "run unbounded" "$VE_OUT" "the unbounded run should be announced"

# 4d. The timeout is opt-out-able entirely.
test_start "validate_examples_honours_timeout_zero"
proj="$(ve_project no_timeout)"
ve_example "$proj" alpha 0
stubs="$WORK/stubs_zero"
mkdir -p "$stubs"
ve_stub "$stubs" timeout 124
VE_TIMEOUT=0 ve_run "$proj" "$stubs"
assert_equals "0" "$VE_RC" \
  "EXAMPLE_TIMEOUT=0 should skip the wrapper, so the 124 stub is never reached"

print_summary
