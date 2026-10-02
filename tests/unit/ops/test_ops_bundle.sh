#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/bundle.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "bundle_exists"
assert_file_exists "$TEST_SCRIPT" "bundle.sh should exist"

# A recording tar: the bundle is a zstd tar of the existing source paths,
# written to the output directory given as the argument.
test_start "bundle_runs_tar_zstd_on_existing_paths"
bundle_bin="$DOTFILES_COV_TMPDIR/bundle-bin"
bundle_out="$DOTFILES_COV_TMPDIR/bundle-out"
mkdir -p "$bundle_bin"
cat >"$bundle_bin/tar" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$TAR_LOG"
[[ "$2" == -cf ]] && : >"$3"
STUB
printf '#!/usr/bin/env bash\nexit 0\n' >"$bundle_bin/zstd"
chmod +x "$bundle_bin/tar" "$bundle_bin/zstd"
bundle_rc=0
TAR_LOG="$DOTFILES_COV_TMPDIR/tar.log" PATH="$bundle_bin:$DOTFILES_COV_TMPDIR/bin:/usr/bin:/bin" \
  bash "$TEST_SCRIPT" "$bundle_out" >/dev/null 2>&1 || bundle_rc=$?
assert_equals "0" "$bundle_rc" "bundle exits 0"
tar_args="$(cat "$DOTFILES_COV_TMPDIR/tar.log" 2>/dev/null || true)"
bundle_re="^--zstd -cf $bundle_out/dotfiles_offline_bundle_[0-9_]+[.]tar[.]zst -P $HOME/[.]dotfiles"
assert_equals "true" "$([[ $tar_args =~ $bundle_re ]] && echo true || echo false)" \
  "tar --zstd writes the bundle from ~/.dotfiles: ${tar_args:-not called}"
assert_equals "false" "$([[ $tar_args == *.local/share/mise* ]] && echo true || echo false)" \
  "a missing path is left out"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
