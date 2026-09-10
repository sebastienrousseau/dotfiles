#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Drift-branch coverage for scripts/qa/check-feature-matrix.sh.
#
# tests/unit/misc/test_qa_check_feature_matrix.sh drives the gate against a
# copy of the *real* tree, which is slow and can only break the handful of
# things the real documents happen to express. This file instead builds a
# tiny synthetic repository — 55 fake commands, a fake route table, a fake
# bench harness — and points the gate at it through the REPO_ROOT override
# the script already exposes. Each case then breaks exactly one invariant,
# so every `fail` arm the gate claims to have is watched firing.
#
# Nothing here touches the checkout: the fixture is a mktemp tree and the
# gate is invoked with REPO_ROOT set to it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

GATE="$REPO_ROOT/scripts/qa/check-feature-matrix.sh"

FIXTURE_BASE="$(mktemp -d -t fmdrift.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$FIXTURE_BASE"; cov_teardown_sandbox' EXIT

# ── Fixture ────────────────────────────────────────────────────────────────
#
# fm_build <dir> — a synthetic repo the gate passes cleanly on. Every later
# case starts from a fresh one of these and breaks a single thing.
#
# 55 commands, because the gate refuses to trust a matrix with fewer than 50
# parsed rows (that guard gets its own case below, with a smaller table).
fm_build() {
  local d="$1" n i cmd
  n="${2:-55}"
  mkdir -p "$d/docs/reference" "$d/docs/manual" "$d/bin" "$d/benches" \
    "$d/tests/regression" "$d/examples" "$d/scripts/dot/commands"

  {
    printf '# Feature matrix\n\n'
    printf '| Command | Variant | Test | Bench | Example | Docs | Coverage |\n'
    printf '| --- | --- | --- | --- | --- | --- | --- |\n'
  } >"$d/docs/reference/FEATURE-MATRIX.md"

  printf '# Command index\n\n' >"$d/docs/manual/command-index.md"

  {
    printf '#!/usr/bin/env bash\n'
    printf '_dot_command_routes() {\n'
    printf '  cat <<EOF\n'
  } >"$d/bin/dot"

  {
    printf '#!/usr/bin/env bash\n'
    printf '# fake bench harness\n'
    printf 'set -euo pipefail\n'
    printf 'if [ "${1:-}" = "--list-ids" ]; then\n'
    printf '  cat <<EOF\n'
  } >"$d/benches/dot_command_bench.sh"

  {
    printf '#!/usr/bin/env bash\n'
    printf '# fake regression suite\n'
  } >"$d/tests/regression/test_feature_matrix_fake.sh"

  i=1
  while [ "$i" -le "$n" ]; do
    cmd="$(printf 'c%02d' "$i")"
    printf '| `dot %s` | — | `test_fm_%s` | `run:%s` | `examples/example-%s.sh` | docs/x.md | regression |\n' \
      "$cmd" "$cmd" "$cmd" "$cmd" >>"$d/docs/reference/FEATURE-MATRIX.md"
    printf '| `dot %s` | fake command |\n' "$cmd" >>"$d/docs/manual/command-index.md"
    printf '%s|core\n' "$cmd" >>"$d/bin/dot"
    printf 'run:%s\nhelp:%s\n' "$cmd" "$cmd" >>"$d/benches/dot_command_bench.sh"
    printf 'test_fm_%s() { :; }\ntest_fm_%s\n' "$cmd" "$cmd" \
      >>"$d/tests/regression/test_feature_matrix_fake.sh"
    printf '#!/usr/bin/env bash\necho %s\n' "$cmd" >"$d/examples/example-$cmd.sh"
    i=$((i + 1))
  done

  printf 'EOF\n}\n' >>"$d/bin/dot"
  printf 'EOF\n  exit 0\nfi\nexit 0\n' >>"$d/benches/dot_command_bench.sh"

  # A defined-but-unreferenced test function. Not an error — the gate reports
  # orphans as information — but the arm that counts them only runs when at
  # least one exists.
  printf 'test_fm_orphan() { :; }\ntest_fm_orphan\n' \
    >>"$d/tests/regression/test_feature_matrix_fake.sh"

  # One command module, demonstrated by one example, so the "every module is
  # referenced by an example" arm passes on a clean fixture.
  printf '#!/usr/bin/env bash\n:\n' >"$d/scripts/dot/commands/fakemod.sh"
  printf '#!/usr/bin/env bash\n# runs scripts/dot/commands/fakemod.sh\n' \
    >"$d/examples/example-fakemod.sh"
}

# fm_fresh — a brand new clean fixture, printed on stdout.
fm_fresh() {
  local d
  d="$(mktemp -d "$FIXTURE_BASE/fx.XXXXXX")"
  fm_build "$d" "${1:-55}"
  printf '%s\n' "$d"
}

# fm_run <dir> [args...] — invoke the real gate against a fixture. stderr is
# left alone so the coverage sweep still sees the gate's xtrace.
fm_run() {
  local d="$1"
  shift
  (cd "$d" && REPO_ROOT="$d" bash "$GATE" "$@")
}

# fm_rc <dir> [args...] — exit status of fm_run, output discarded.
fm_rc() {
  local rc=0
  fm_run "$@" >/dev/null 2>/dev/null || rc=$?
  printf '%s\n' "$rc"
}

# ── 0. The clean fixture really is clean ───────────────────────────────────
fx="$(fm_fresh)"
test_start "feature_matrix_fixture_is_clean"
assert_equals "0" "$(fm_rc "$fx" --quiet)" "synthetic repo should pass the gate"

test_start "feature_matrix_fixture_is_clean_when_loud"
assert_equals "0" "$(fm_rc "$fx")" "the non-quiet path should also pass"

# ── 1. Usage surface ───────────────────────────────────────────────────────
test_start "feature_matrix_help_flag"
assert_equals "0" "$(fm_rc "$fx" --help)" "--help should exit 0"

test_start "feature_matrix_help_prints_usage"
assert_contains "Usage:" "$(fm_run "$fx" -h 2>/dev/null)" \
  "-h should print the usage block"

test_start "feature_matrix_rejects_unknown_option"
assert_equals "2" "$(fm_rc "$fx" --bogus)" "an unknown option should exit 2"

test_start "feature_matrix_short_quiet_flag"
assert_equals "0" "$(fm_rc "$fx" -q)" "-q should be accepted as --quiet"

# ── 2. A dependency the gate needs is missing ──────────────────────────────
fx="$(fm_fresh)"
rm -f "$fx/bin/dot"
test_start "feature_matrix_missing_dependency_exits_2"
assert_equals "2" "$(fm_rc "$fx" --quiet)" "a missing bin/dot should exit 2"

# ── 3. A matrix too small to trust ─────────────────────────────────────────
fx="$(fm_fresh 5)"
test_start "feature_matrix_rejects_a_truncated_table"
assert_equals "1" "$(fm_rc "$fx" --quiet)" "fewer than 50 rows should fail"

test_start "feature_matrix_truncated_table_says_why"
assert_contains "rows parsed" "$(fm_run "$fx" --quiet 2>&1)" \
  "the truncated-table failure should name the row count"

# ── 4. A documented command with no row ────────────────────────────────────
fx="$(fm_fresh)"
printf '| `dot ghostdoc` | documented but unrowed |\n' \
  >>"$fx/docs/manual/command-index.md"
test_start "feature_matrix_detects_documented_command_with_no_row"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a command in the index but not the matrix should fail"

# ── 4b. A routable command whose row has been deleted ──────────────────────
fx="$(fm_fresh)"
grep -v '^| `dot c02`' "$fx/docs/reference/FEATURE-MATRIX.md" \
  >"$fx/docs/reference/FEATURE-MATRIX.md.new"
mv "$fx/docs/reference/FEATURE-MATRIX.md.new" "$fx/docs/reference/FEATURE-MATRIX.md"
test_start "feature_matrix_detects_a_routable_command_with_no_row"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a routable command with no matrix row should fail"

test_start "feature_matrix_unrowed_command_is_named"
assert_contains "no FEATURE-MATRIX row: dot c02" "$(fm_run "$fx" --quiet 2>&1)" \
  "the unrowed-command failure should name the command"

# ── 5. A phantom row — neither routable nor documented ─────────────────────
fx="$(fm_fresh)"
printf '| `dot phantom` | — | `test_fm_c01` | `run:c01` | `examples/example-c01.sh` | docs/x.md | regression |\n' \
  >>"$fx/docs/reference/FEATURE-MATRIX.md"
test_start "feature_matrix_detects_a_phantom_row"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a row for a command that does not exist should fail"

test_start "feature_matrix_phantom_row_names_the_command"
assert_contains "phantom" "$(fm_run "$fx" --quiet 2>&1)" \
  "the phantom failure should name the offending command"

# ── 6. No regression suite defines any matrix test function ────────────────
#
# The gate carries a `fail "no test functions found"` arm for this, but it
# cannot be reached: the `grep … $TEST_GLOB | sed | sort` pipeline that fills
# defined-tests.txt runs at the top level under `set -euo pipefail`, so an
# unmatched glob aborts the script with grep's own status (2) before the
# emptiness check runs. The gate still refuses to pass, which is the property
# that matters, so this asserts what actually happens rather than pretending
# the arm is live.
fx="$(fm_fresh)"
rm -f "$fx"/tests/regression/test_feature_matrix_*.sh
test_start "feature_matrix_refuses_an_empty_regression_tier"
assert_equals "2" "$(fm_rc "$fx" --quiet)" \
  "an empty regression tier should abort the gate, not pass it"

# ── 7. A named function that is defined but never invoked ──────────────────
fx="$(fm_fresh)"
grep -v '^test_fm_c07$' "$fx/tests/regression/test_feature_matrix_fake.sh" \
  >"$fx/tests/regression/test_feature_matrix_fake.sh.new"
mv "$fx/tests/regression/test_feature_matrix_fake.sh.new" \
  "$fx/tests/regression/test_feature_matrix_fake.sh"
test_start "feature_matrix_detects_an_uninvoked_test_function"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a defined-but-never-called test function should fail"

test_start "feature_matrix_uninvoked_function_is_named"
assert_contains "never called" "$(fm_run "$fx" --quiet 2>&1)" \
  "the uninvoked-function failure should say so"

# ── 7b. A row naming a test function nothing defines ───────────────────────
fx="$(fm_fresh)"
sed 's/`test_fm_c06`/`test_fm_no_such_function`/' \
  "$fx/docs/reference/FEATURE-MATRIX.md" >"$fx/docs/reference/FEATURE-MATRIX.md.new"
mv "$fx/docs/reference/FEATURE-MATRIX.md.new" "$fx/docs/reference/FEATURE-MATRIX.md"
test_start "feature_matrix_detects_an_undefined_test_function"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a row naming a function nothing defines should fail"

test_start "feature_matrix_undefined_function_is_named"
assert_contains "test_fm_no_such_function" "$(fm_run "$fx" --quiet 2>&1)" \
  "the undefined-function failure should name the function"

# ── 8. A benchmark id the harness does not produce ─────────────────────────
fx="$(fm_fresh)"
sed 's/`run:c03`/`run:no-such-bench`/' "$fx/docs/reference/FEATURE-MATRIX.md" \
  >"$fx/docs/reference/FEATURE-MATRIX.md.new"
mv "$fx/docs/reference/FEATURE-MATRIX.md.new" "$fx/docs/reference/FEATURE-MATRIX.md"
test_start "feature_matrix_detects_an_unknown_benchmark_id"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a benchmark id the harness cannot produce should fail"

# ── 9. A routable command with no cold-start benchmark ─────────────────────
fx="$(fm_fresh)"
grep -v '^help:c04$' "$fx/benches/dot_command_bench.sh" \
  >"$fx/benches/dot_command_bench.sh.new"
mv "$fx/benches/dot_command_bench.sh.new" "$fx/benches/dot_command_bench.sh"
test_start "feature_matrix_detects_a_missing_cold_start_benchmark"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a routable command with no help: benchmark should fail"

test_start "feature_matrix_missing_benchmark_is_named"
assert_contains "cold-start benchmark" "$(fm_run "$fx" --quiet 2>&1)" \
  "the missing-benchmark failure should say what is missing"

# ── 10. The benchmark harness cannot list its ids at all ───────────────────
fx="$(fm_fresh)"
printf '#!/usr/bin/env bash\nexit 1\n' >"$fx/benches/dot_command_bench.sh"
test_start "feature_matrix_detects_an_unlistable_bench_harness"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a harness that cannot list ids should fail"

test_start "feature_matrix_unlistable_harness_is_reported"
assert_contains "could not list benchmark ids" "$(fm_run "$fx" --quiet 2>&1)" \
  "the unlistable-harness failure should say so"

# ── 11. An example that exists but lives outside examples/ ─────────────────
fx="$(fm_fresh)"
mkdir -p "$fx/docs/samples"
printf '#!/usr/bin/env bash\n:\n' >"$fx/docs/samples/stray.sh"
sed 's|`examples/example-c05.sh`|`docs/samples/stray.sh`|' \
  "$fx/docs/reference/FEATURE-MATRIX.md" >"$fx/docs/reference/FEATURE-MATRIX.md.new"
mv "$fx/docs/reference/FEATURE-MATRIX.md.new" "$fx/docs/reference/FEATURE-MATRIX.md"
test_start "feature_matrix_detects_an_example_outside_examples_dir"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "an example outside examples/*.sh should fail"

test_start "feature_matrix_stray_example_is_reported"
assert_contains "outside the directory" "$(fm_run "$fx" --quiet 2>&1)" \
  "the stray-example failure should explain the rule"

# ── 11b. An example the matrix names but the tree does not carry ───────────
fx="$(fm_fresh)"
sed 's|`examples/example-c09.sh`|`examples/example-vanished.sh`|' \
  "$fx/docs/reference/FEATURE-MATRIX.md" >"$fx/docs/reference/FEATURE-MATRIX.md.new"
mv "$fx/docs/reference/FEATURE-MATRIX.md.new" "$fx/docs/reference/FEATURE-MATRIX.md"
test_start "feature_matrix_detects_a_missing_example"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a row naming an example that does not exist should fail"

test_start "feature_matrix_missing_example_is_named"
assert_contains "example-vanished.sh" "$(fm_run "$fx" --quiet 2>&1)" \
  "the missing-example failure should name the path"

# ── 12. A command module no example demonstrates ───────────────────────────
fx="$(fm_fresh)"
printf '#!/usr/bin/env bash\n:\n' >"$fx/scripts/dot/commands/orphanmod.sh"
test_start "feature_matrix_detects_an_undemonstrated_module"
assert_equals "1" "$(fm_rc "$fx" --quiet)" \
  "a command module with no example should fail"

test_start "feature_matrix_undemonstrated_module_is_named"
assert_contains "orphanmod.sh" "$(fm_run "$fx" --quiet 2>&1)" \
  "the undemonstrated-module failure should name the module"

print_summary
