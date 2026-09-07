#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Behavioural coverage for the rename helpers kebabcase / titlecase /
# uppercase: the rename branch, the already-converted skip branch and
# the mv-failure branch (driven by a PATH-shadowed `mv` that refuses).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep bash xtrace flowing to the coverage runner's trace stream even
# when a probe below captures 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

FUNCS_DIR="$REPO_ROOT/defaults/.chezmoitemplates/functions/text"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

fail_bin="$DOTFILES_COV_TMPDIR/failing-mv"
mkdir -p "$fail_bin"
cat >"$fail_bin/mv" <<'EOF'
#!/usr/bin/env bash
echo "mv-shim refusing: $*" >&2
exit 1
EOF
chmod +x "$fail_bin/mv"

# run_fn <function-file> <fn> <args...> — child bash, cwd = sandbox.
run_fn() {
  local file="$1" fn="$2"
  shift 2
  bash -c 'source "$1"; shift; "$@"' _ "$file" "$fn" "$@"
}

work="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$work"

# ── kebabcase ────────────────────────────────────────────────────
test_start "kebabcase_renames_mixed_name"
touch "$work/My File.txt"
out="$(run_fn "$FUNCS_DIR/kebabcase.sh" kebabcase "$work/My File.txt" 2>&1)"
assert_equals 0 "$?" "rename exits 0"
assert_contains "Renamed '$work/My File.txt' to '$work/my-file.txt'" "$out" "reports the rename"
assert_file_exists "$work/my-file.txt" "kebab-case file created"
assert_file_not_exists "$work/My File.txt" "original name gone"

test_start "kebabcase_skips_already_kebab"
out="$(run_fn "$FUNCS_DIR/kebabcase.sh" kebabcase "$work/my-file.txt" 2>&1)"
assert_contains "already in kebab-case" "$out" "skip message printed"

test_start "kebabcase_reports_mv_failure"
touch "$work/Kebab Fail.txt"
out="$(PATH="$fail_bin:$PATH" run_fn "$FUNCS_DIR/kebabcase.sh" kebabcase "$work/Kebab Fail.txt" 2>&1)"
assert_contains "[ERROR] Failed to rename '$work/Kebab Fail.txt'" "$out" "mv failure surfaced"
assert_file_exists "$work/Kebab Fail.txt" "file untouched when mv fails"

test_start "kebabcase_missing_path_and_no_args"
out="$(run_fn "$FUNCS_DIR/kebabcase.sh" kebabcase "$work/nope" 2>&1)"
assert_contains "does not exist" "$out" "missing path reported"
out="$(run_fn "$FUNCS_DIR/kebabcase.sh" kebabcase 2>&1)"
assert_equals 1 "$?" "no-arg exits 1"

# ── titlecase ────────────────────────────────────────────────────
test_start "titlecase_renames_upper_name"
touch "$work/MYFILE.TXT"
out="$(run_fn "$FUNCS_DIR/titlecase.sh" titlecase "$work/MYFILE.TXT" 2>&1)"
assert_equals 0 "$?" "rename exits 0"
assert_file_exists "$work/Myfile.txt" "title-case file created"
assert_contains "Renamed" "$out" "reports the rename"

test_start "titlecase_skips_already_titlecase"
out="$(run_fn "$FUNCS_DIR/titlecase.sh" titlecase "$work/Myfile.txt" 2>&1)"
assert_contains "already in title case" "$out" "skip message printed"

test_start "titlecase_reports_mv_failure"
touch "$work/TITLEFAIL.TXT"
out="$(PATH="$fail_bin:$PATH" run_fn "$FUNCS_DIR/titlecase.sh" titlecase "$work/TITLEFAIL.TXT" 2>&1)"
assert_contains "[ERROR] Failed to rename '$work/TITLEFAIL.TXT'" "$out" "mv failure surfaced"

test_start "titlecase_missing_path_and_no_args"
out="$(run_fn "$FUNCS_DIR/titlecase.sh" titlecase "$work/nope" 2>&1)"
assert_contains "does not exist" "$out" "missing path reported"
out="$(run_fn "$FUNCS_DIR/titlecase.sh" titlecase 2>&1)"
assert_equals 1 "$?" "no-arg exits 1"

# ── uppercase ────────────────────────────────────────────────────
test_start "uppercase_renames_lower_name"
touch "$work/lower.txt"
out="$(run_fn "$FUNCS_DIR/uppercase.sh" uppercase "$work/lower.txt" 2>&1)"
assert_equals 0 "$?" "rename exits 0"
assert_file_exists "$work/LOWER.TXT" "uppercase file created"
assert_contains "Renamed" "$out" "reports the rename"

test_start "uppercase_skips_already_upper"
out="$(run_fn "$FUNCS_DIR/uppercase.sh" uppercase "$work/LOWER.TXT" 2>&1)"
assert_contains "already in uppercase" "$out" "skip message printed"

test_start "uppercase_reports_mv_failure"
touch "$work/upperfail.txt"
out="$(PATH="$fail_bin:$PATH" run_fn "$FUNCS_DIR/uppercase.sh" uppercase "$work/upperfail.txt" 2>&1)"
assert_contains "[ERROR] Failed to rename '$work/upperfail.txt'" "$out" "mv failure surfaced"

test_start "uppercase_missing_path_and_no_args"
out="$(run_fn "$FUNCS_DIR/uppercase.sh" uppercase "$work/nope" 2>&1)"
assert_contains "does not exist" "$out" "missing path reported"
out="$(run_fn "$FUNCS_DIR/uppercase.sh" uppercase 2>&1)"
assert_equals 1 "$?" "no-arg exits 1"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
