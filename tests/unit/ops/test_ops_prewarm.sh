#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/prewarm.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "prewarm_exists"
assert_file_exists "$TEST_SCRIPT" "prewarm.sh should exist"

# starship prints its init; zoxide fails and atuin prints nothing. Only the
# first is cached, per shell; the others leave no file behind.
test_start "prewarm_caches_tool_init_output"
prewarm_bin="$DOTFILES_COV_TMPDIR/prewarm-bin"
mkdir -p "$prewarm_bin"
printf '#!/usr/bin/env bash\necho "starship $*"\n' >"$prewarm_bin/starship"
printf '#!/usr/bin/env bash\nexit 1\n' >"$prewarm_bin/zoxide"
printf '#!/usr/bin/env bash\nexit 0\n' >"$prewarm_bin/atuin"
chmod +x "$prewarm_bin/starship" "$prewarm_bin/zoxide" "$prewarm_bin/atuin"
prewarm_rc=0
XDG_RUNTIME_DIR="$DOTFILES_COV_TMPDIR" PATH="$prewarm_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" \
  bash "$TEST_SCRIPT" >/dev/null 2>&1 || prewarm_rc=$?
assert_equals "0" "$prewarm_rc" "prewarm exits 0"
assert_equals "starship init zsh" "$(cat "$XDG_CACHE_HOME/zsh/starship-init.zsh" 2>&1)" "zsh init cached"
assert_equals "starship init nu" "$(cat "$XDG_CACHE_HOME/nushell/starship.nu" 2>&1)" "nushell init cached"
assert_equals "" "$(find "$XDG_CACHE_HOME" -name 'zoxide*' 2>/dev/null)" "a failing tool leaves no file"
assert_equals "" "$(find "$XDG_CACHE_HOME" -name 'atuin*' 2>/dev/null)" "empty output is not cached"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
