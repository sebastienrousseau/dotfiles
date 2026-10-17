#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The standards sentinel (rc.d/45-standards.zsh) runs a Python check that
# costs ~50ms, so it must not run in every new shell: at most once a day
# while the standards are in sync, and in every shell while they drift.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SENTINEL="$REPO_ROOT/defaults/dot_config/zsh/rc.d/45-standards.zsh"

if ! command -v zsh >/dev/null 2>&1; then
  echo "SKIP: zsh is required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin" "$SANDBOX/home"
CALLS="$SANDBOX/calls.log"
STAMP="$SANDBOX/home/.cache/dotfiles/standards-check.stamp"

# A stub standards-sync: records each call, exits with $STUB_RC.
cat >"$SANDBOX/bin/standards-sync" <<EOF
#!/bin/sh
echo "\$*" >>"$CALLS"
exit "\${STUB_RC:-0}"
EOF
chmod +x "$SANDBOX/bin/standards-sync"

# new_shell [VAR=value...]: source the sentinel as a fresh interactive zsh would.
new_shell() {
  env -i HOME="$SANDBOX/home" PATH="$SANDBOX/bin:/usr/bin:/bin" "$@" \
    zsh -f -c "source '$SENTINEL'"
}
calls() { [[ -f "$CALLS" ]] && wc -l <"$CALLS" | tr -d ' ' || echo 0; }

test_start "sentinel_is_valid_zsh"
assert_exit_code 0 "zsh -n '$SENTINEL'"

test_start "first_shell_runs_the_check"
new_shell
assert_equals "1|--check --quiet" "$(calls)|$(head -1 "$CALLS")" "the first shell checks"

test_start "a_passing_check_is_not_repeated_within_a_day"
new_shell
new_shell
assert_equals "1" "$(calls)" "later shells reuse the passing result"

test_start "a_day_old_result_is_checked_again"
touch -t "$(date -v-25H +%Y%m%d%H%M 2>/dev/null || date -d '25 hours ago' +%Y%m%d%H%M)" "$STAMP"
new_shell
assert_equals "2" "$(calls)" "a stale stamp triggers a new check"

test_start "drift_is_reported_in_every_shell"
rm -f "$STAMP" "$CALLS"
new_shell STUB_RC=1
new_shell STUB_RC=1
assert_equals "2" "$(calls)" "a drifted result is never cached"

test_start "drift_does_not_fail_shell_startup"
rm -f "$STAMP"
assert_exit_code 0 "env -i HOME='$SANDBOX/home' PATH='$SANDBOX/bin:/usr/bin:/bin' STUB_RC=1 zsh -f -c \"source '$SENTINEL'\""

test_start "opt_out_skips_the_check"
rm -f "$STAMP" "$CALLS"
new_shell DOTFILES_STANDARDS_CHECK=0
assert_equals "0" "$(calls)" "DOTFILES_STANDARDS_CHECK=0 runs nothing"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
