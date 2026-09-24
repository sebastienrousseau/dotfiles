#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural except tools/ci/check-source-grep-tests.py
# shellcheck disable=SC1090,SC1091,SC2016
# The source-grep ratchet (tools/ci/check-source-grep-tests.py) must flag a
# test that inspects source text, pass one that runs the code, skip a
# declared structural test, and hold every file at or below its baseline
# ceiling. Each case runs the lint on a throwaway repo with three tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LINT="$REPO_ROOT/tools/ci/check-source-grep-tests.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/srcgrep-lint.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/repo/scripts" "$WORK/repo/tests/unit" "$WORK/repo/tools/ci"
printf '#!/usr/bin/env bash\necho ok\n' >"$WORK/repo/scripts/thing.sh"

# Greps the source through a variable, through a literal path, and inside
# an assignment's command substitution: three hits.
cat >"$WORK/repo/tests/unit/test_greps.sh" <<'EOF'
#!/usr/bin/env bash
THING="$REPO_ROOT/scripts/thing.sh"
assert_file_contains "$THING" "echo ok" "prints ok"
grep -q 'echo' "$REPO_ROOT/scripts/thing.sh"
first_line=$(head -n 1 "$THING")
bash "$THING" >/dev/null
EOF
# Runs the code and asserts on its output: no hits.
cat >"$WORK/repo/tests/unit/test_runs.sh" <<'EOF'
#!/usr/bin/env bash
THING="$REPO_ROOT/scripts/thing.sh"
out="$(bash "$THING")"
[[ "$out" == ok ]] || exit 1
grep -q ok <<<"$out"
EOF
# Declared structural: greps source by design, skipped by the lint.
cat >"$WORK/repo/tests/unit/test_lint.sh" <<'EOF'
#!/usr/bin/env bash
# test-kind: structural
grep -q '#!/usr/bin/env bash' "$REPO_ROOT/scripts/thing.sh"
EOF

run_lint() {
  rc=0
  (cd "$WORK/repo" && python3 "$LINT" "$@") >"$WORK/out" 2>"$WORK/err" || rc=$?
}

# ── No baseline: every finding fails, with file:line ───────────────
test_start "srcgrep_flags_source_inspection_without_baseline"
run_lint
assert_equals "1" "$rc" "exit 1 on findings"
assert_file_contains "$WORK/out" "tests/unit/test_greps.sh:3: assert_file_contains reads source \$THING" "variable operand named"
assert_file_contains "$WORK/out" "tests/unit/test_greps.sh:4: grep reads source scripts/thing.sh" "literal operand named"
assert_file_contains "$WORK/out" "tests/unit/test_greps.sh:5: head reads source \$THING" "assignment substitution named"
assert_equals "0" "$(grep -c 'test_runs.sh' "$WORK/out")" "a test that runs the code is not flagged"
assert_equals "0" "$(grep -c 'test_lint.sh' "$WORK/out")" "a declared structural test is skipped"
assert_file_contains "$WORK/err" "3 line(s) inspect source text (3 tests scanned)" "totals reported"

# ── --report never fails ───────────────────────────────────────────
test_start "srcgrep_report_mode_only_counts"
run_lint --report
assert_equals "0" "$rc" "report mode exits 0"
assert_equals "0" "$(wc -c <"$WORK/out" | tr -d ' ')" "report mode prints no findings"

# ── --write-baseline records the ceiling and the lint then passes ──
test_start "srcgrep_baseline_written_and_honoured"
run_lint --write-baseline
assert_equals "0" "$rc" "writing the baseline succeeds"
assert_file_contains "$WORK/repo/tools/ci/source-grep-baseline.txt" "   3 tests/unit/test_greps.sh" "ceiling recorded per file"
run_lint
assert_equals "0" "$rc" "at the ceiling the lint passes"

# ── Above the ceiling, or a new file, fails ─────────────────────────
test_start "srcgrep_regression_above_ceiling_fails"
printf 'grep -q ok "$THING"\n' >>"$WORK/repo/tests/unit/test_greps.sh"
run_lint
assert_equals "1" "$rc" "one more source grep fails"
assert_file_contains "$WORK/err" "tests/unit/test_greps.sh: 4 line(s), ceiling 3" "names the file and ceiling"
test_start "srcgrep_new_file_not_in_baseline_fails"
sed -i.bak '$d' "$WORK/repo/tests/unit/test_greps.sh" && rm -f "$WORK/repo/tests/unit/test_greps.sh.bak"
printf '#!/usr/bin/env bash\nassert_file_contains "$REPO_ROOT/scripts/thing.sh" ok\n' >"$WORK/repo/tests/unit/test_newgrep.sh"
run_lint
assert_equals "1" "$rc" "a new source-grep test fails"
assert_file_contains "$WORK/err" "tests/unit/test_newgrep.sh: not in the baseline" "names the new file"
rm -f "$WORK/repo/tests/unit/test_newgrep.sh"

# ── Below the ceiling passes and invites a ratchet ─────────────────
test_start "srcgrep_below_ceiling_passes_and_suggests_ratchet"
sed -i.bak '/^grep -q .echo/d' "$WORK/repo/tests/unit/test_greps.sh" && rm -f "$WORK/repo/tests/unit/test_greps.sh.bak"
run_lint
assert_equals "0" "$rc" "below the ceiling passes"
assert_file_contains "$WORK/err" "1 line(s) below the ceiling" "ratchet suggested"

# ── Feature-matrix rows that accept 0 or 1 with no outcome assertion ─
test_start "srcgrep_flags_permissive_feature_matrix_rows"
cat >"$WORK/repo/tests/unit/test_fm_rows.sh" <<'EOF'
#!/usr/bin/env bash
test_fm_bare() {
  fm_run thing
  fm_expect_rc_in 0 1
}
test_fm_with_outcome() {
  fm_run thing
  fm_expect_rc_in 0 1 # host-dependent: explained here
  fm_expect_out "ok"
}
test_fm_exact() {
  fm_run thing
  fm_expect_rc 0
}
EOF
run_lint tests/unit/test_fm_rows.sh
assert_equals "1" "$rc" "a bare permissive row fails"
assert_file_contains "$WORK/out" "tests/unit/test_fm_rows.sh:4: fm_expect_rc_in 0 1 with no outcome assertion" "the bare row is named"
assert_equals "1" "$(grep -c 'fm_expect_rc_in' "$WORK/out")" "a permissive row with an outcome assertion is not flagged"
rm -f "$WORK/repo/tests/unit/test_fm_rows.sh"

# ── The real tree is at or below its baseline ──────────────────────
test_start "srcgrep_repo_holds_its_baseline"
rc=0
(cd "$REPO_ROOT" && python3 "$LINT") >"$WORK/repo.out" 2>"$WORK/repo.err" || rc=$?
assert_equals "0" "$rc" "no test file exceeds tools/ci/source-grep-baseline.txt"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
