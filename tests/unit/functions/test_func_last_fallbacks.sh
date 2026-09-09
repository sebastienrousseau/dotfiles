#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The fallbacks in the `last` function.
#
# Two clusters had never run. The minimal logging shims at the top only
# define themselves when ../utils/logging.sh is absent, which in the checkout
# it never is; a fixture tree that carries last.sh but not its sibling makes
# that arm the one taken. And the `fd` and unknown-tool arms of the dispatch
# are unreachable while detect_tool answers "find", which it always does on a
# host that has /usr/bin/find — so those cases substitute detect_tool and
# assert on what `last` does with the answer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

LAST_REL="defaults/.chezmoitemplates/functions/misc/last.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

# Not removed on exit: the aggregator resolves the symlink after the whole
# sweep has run, and a deleted fixture would resolve to nothing.
FX="${TMPDIR:-/tmp}"
FX="${FX%/}/dot-cov-fixtures/last-fallbacks"
rm -rf "$FX"
mkdir -p "$FX/$(dirname "$LAST_REL")" "$FX/work"
ln -s "$REPO_ROOT/$LAST_REL" "$FX/$LAST_REL"
: >"$FX/work/recent.txt"

# last_run <extra-shell-code> — source last.sh from the fixture (so its
# sibling logging library is genuinely absent) and run the given code.
LAST_OUT=""
LAST_RC=0
last_run() {
  local runner="$FX/runner.sh"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -uo pipefail\n'
    printf 'cd "%s" || exit 1\n' "$FX"
    printf 'source %s\n' "$LAST_REL"
    printf '%s\n' "$1"
  } >"$runner"
  LAST_RC=0
  LAST_OUT="$(cd "$FX/work" && "${BASH:-bash}" "$runner" 2>&1 </dev/null)" || LAST_RC=$?
}

# ── 1. The minimal logging shims ───────────────────────────────────────────
test_start "last_defines_fallback_logging_without_its_sibling_library"
last_run 'log_info "hello from the fallback"; log_warning "warned"; log_error "failed"'
assert_contains "[INFO] hello from the fallback" "$LAST_OUT" \
  "the fallback log_info should be defined"
assert_contains "[WARNING] warned" "$LAST_OUT" "the fallback log_warning should be defined"
assert_contains "[ERROR] failed" "$LAST_OUT" "the fallback log_error should be defined"

# ── 2. Input validation ────────────────────────────────────────────────────
test_start "last_rejects_a_non_numeric_range"
last_run 'last abc'
assert_equals "1" "$LAST_RC" "a non-numeric minute count should return 1"
assert_contains "Invalid input" "$LAST_OUT" "the failure should say why"

test_start "last_rejects_a_range_beyond_seven_days"
last_run 'last 10081'
assert_equals "1" "$LAST_RC" "more than seven days should return 1"
assert_contains "Time range too large" "$LAST_OUT" "the failure should say why"

# ── 3. Tool dispatch ───────────────────────────────────────────────────────
#
# detect_tool is substituted rather than coerced: hiding /usr/bin/find from a
# process is not something a test can do, and what is under test here is what
# `last` does with each answer.
test_start "last_uses_fd_when_that_is_the_detected_tool"
last_run 'detect_tool() { echo fd; }
fd() { printf "fd called: %s\n" "$*"; }
last 30'
assert_contains "fd called: --type file --changed-within 30m" "$LAST_OUT" \
  "the fd arm should pass the window through in fd's own units"

test_start "last_rejects_an_unrecognised_tool"
last_run 'detect_tool() { echo something-else; }
last 30'
assert_equals "1" "$LAST_RC" "an unrecognised tool should return 1"
assert_contains "Unknown tool detected" "$LAST_OUT" "the failure should say so"

test_start "last_uses_find_by_default"
last_run 'last 30'
assert_equals "0" "$LAST_RC" "the default path should succeed"
assert_contains "using find" "$LAST_OUT" "find should be the detected tool"

print_summary
