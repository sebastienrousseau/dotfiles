#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# =============================================================================
# Regression test for the tools/ci/run-coverage.sh aggregator.
#
# The runner decides which physical lines belong in the lcov denominator.
# Bash's `set -x` never emits a record for several kinds of line even when
# the code runs (function headers, `case` labels, the interior of a
# multi-line `$( )` / array / quoted string, plain backslash continuations,
# `done <file`), so counting them made per-file coverage permanently
# unreachable and capped real files at 86-97%.
#
# This test pins that decision. It builds a sandbox of fixtures — one per
# construct, written so that EVERY statement in them executes — drives the
# REAL runner over them, and asserts:
#
#   1. the emitted denominator (the DA: line numbers) matches an
#      expected set exactly, so a change to the classifier is visible; and
#   2. every one of those lines is hit, i.e. each fixture measures 100%.
#
# (2) is the load-bearing half: if the classifier ever re-admits a line
# that bash cannot emit a record for, that fixture stops being 100% and
# this test fails, naming the line.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

RUNNER="$REPO_ROOT/tools/ci/run-coverage.sh"

test_start "runner_exists"
assert_file_exists "$RUNNER" "run-coverage.sh must exist"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
# Resolve symlinks (/tmp -> /private/tmp on macOS) so the paths the
# aggregator resolves match the ones this test compares against.
SANDBOX="$(cd "$SANDBOX" && pwd -P)"
mkdir -p "$SANDBOX/src" "$SANDBOX/tests/unit" "$SANDBOX/tests/regression"

# -----------------------------------------------------------------------------
# Fixtures. Each one exercises every statement it contains, so anything left
# uncovered is a line bash cannot trace and the classifier wrongly kept.
# -----------------------------------------------------------------------------

# Function-definition headers: `name() {`, `function name {`, the split
# `name()` + `{` form. Only the one-liner form is traceable, because its
# body sits on the header line.
cat >"$SANDBOX/src/funcs.sh" <<'FIXTURE'
#!/usr/bin/env bash
# headers below are never traced by `set -x`
greet() {
  echo "hi"
}
function fdecl {
  echo "fdecl"
}
split()
{
  echo "split"
}
oneline() { echo "oneline"; }
greet
fdecl
split
oneline
FIXTURE
EXPECT_funcs="4 7 11 13 14 15 16 17"

# `case` labels: quoted, alternation, star, and the same-line arm (which
# IS traced, because the body runs on that line).
cat >"$SANDBOX/src/cases.sh" <<'FIXTURE'
#!/usr/bin/env bash
for word in "hello world" alpha beta gamma "x y"; do
  case "$word" in
    "hello world")
      echo "quoted"
      ;;
    alpha | beta)
      echo "alternation"
      ;;
    gamma) echo "same line" ;;
    *)
      echo "star"
      ;;
  esac
done
echo "cases done"
FIXTURE
EXPECT_cases="2 3 5 8 10 12 16"

# Multi-line words: command substitution, array assignment, arithmetic
# substitution, backticks, nested substitution, and process substitution
# in both `done <` and simple-command positions.
cat >"$SANDBOX/src/subst.sh" <<'FIXTURE'
#!/usr/bin/env bash
value=$(
  echo "one"
  echo "two"
)
echo "$value" >/dev/null
items=(
  alpha
  beta
)
echo "${items[1]}" >/dev/null
total=$((
  1 + 2
))
echo "$total" >/dev/null
legacy=`
echo "legacy"
`
echo "$legacy" >/dev/null
printed=$(echo "$(
  echo "nested"
)")
echo "$printed" >/dev/null
while IFS= read -r entry; do
  echo "entry=$entry" >/dev/null
done < <(
  printf '%s\n' a b
)
mapfile -t collected < <(
  printf '%s\n' c
)
echo "${collected[0]}" >/dev/null
FIXTURE
EXPECT_subst="2 6 7 11 12 15 16 19 20 23 24 25 26 29 32"

# Continuations: plain backslash-joined words (untraceable) versus a
# continuation that starts a new command (traced at its own line), plus a
# multi-line double-quoted string.
cat >"$SANDBOX/src/contin.sh" <<'FIXTURE'
#!/usr/bin/env bash
printf '%s %s %s\n' \
  "one" \
  "two" \
  "three" >/dev/null
true \
  && echo "and-then" >/dev/null
false \
  || echo "or-else" >/dev/null
echo "first" \
  | cat >/dev/null
message="line-one
line-two
line-three"
echo "$message" >/dev/null
true && \
  echo "tail-operator" >/dev/null
FIXTURE
EXPECT_contin="2 6 7 8 9 10 11 12 15 16 17"

# Compound terminators carrying a redirection are not traced; a
# terminator that starts a pipeline element is.
cat >"$SANDBOX/src/terminators.sh" <<'FIXTURE'
#!/usr/bin/env bash
src="$(mktemp)"
printf 'a\nb\n' >"$src"
while IFS= read -r line; do
  echo "read=$line" >/dev/null
done <"$src"
if true; then
  echo "in-if" >/dev/null
fi >/dev/null
{
  echo "in-brace"
} >/dev/null
for i in 1 2; do
  echo "loop=$i"
done | cat >/dev/null
rm -f "$src"
FIXTURE
EXPECT_terminators="2 3 4 5 7 8 11 13 14 15 16"

# Ordinary code plus here-documents, to prove the classifier still counts
# real statements and still drops here-doc bodies.
cat >"$SANDBOX/src/plain.sh" <<'FIXTURE'
#!/usr/bin/env bash
# a comment

set -u
count=0
for i in 1 2 3; do
  if [[ $((i % 2)) -eq 0 ]]; then
    count=$((count + 1))
  else
    count=$((count + 10))
  fi
done
cat >/dev/null <<'EOF'
heredoc body line
not code
EOF
cat >/dev/null <<-EOT
  indented body
EOT
echo "count=$count" >/dev/null
FIXTURE
EXPECT_plain="4 5 6 7 8 10 13 17 20"

FIXTURES="funcs cases subst contin terminators plain"

# Driver: runs every fixture so that all of their statements execute.
{
  echo '#!/usr/bin/env bash'
  echo '# SPDX-License-Identifier: MIT'
  echo 'SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../src" && pwd)"'
  for name in $FIXTURES; do
    echo "bash \"\$SRC/${name}.sh\" >/dev/null || true"
  done
  echo 'echo "RESULTS:1:1:0"'
} >"$SANDBOX/tests/unit/test_drive_fixtures.sh"

# -----------------------------------------------------------------------------
# Drive the real runner over the sandbox.
# -----------------------------------------------------------------------------
test_start "aggregator_runs_over_fixtures"
runner_log="$SANDBOX/runner.log"
set +e
env -u COV_TEST_TIMEOUT \
  REPO_ROOT="$SANDBOX" \
  TESTS_DIR="$SANDBOX/tests" \
  COVERAGE_DIR="$SANDBOX/coverage" \
  COVERAGE_OUT="$SANDBOX/coverage/lcov.info" \
  COV_INCLUDE_DIRS="$SANDBOX/src" \
  MIN_COVERAGE_PCT=0 \
  JOBS=2 \
  bash "$RUNNER" >"$runner_log" 2>&1
runner_ec=$?
if [[ "$runner_ec" -eq 0 && -s "$SANDBOX/coverage/lcov.info" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: runner exit $runner_ec"
  sed -n '1,40p' "$runner_log" >&2
fi

# Extract "<lineno> <hits>" for one SF: block.
lcov_block() {
  awk -v want="$1" '
    $0 == "SF:" want { inblock = 1; next }
    inblock && /^end_of_record/ { inblock = 0 }
    inblock && /^DA:/ {
      sub(/^DA:/, "")
      split($0, parts, ",")
      print parts[1], parts[2]
    }
  ' "$SANDBOX/coverage/lcov.info"
}

for name in $FIXTURES; do
  sf="$SANDBOX/src/${name}.sh"
  expected_var="EXPECT_${name}"
  expected="${!expected_var}"

  test_start "denominator_exact_${name}"
  actual="$(lcov_block "$sf" | awk '{print $1}' | sort -n | tr '\n' ' ')"
  actual="${actual% }"
  expected_norm="$(printf '%s\n' $expected | sort -n | tr '\n' ' ')"
  expected_norm="${expected_norm% }"
  assert_equals "$expected_norm" "$actual" \
    "${name}.sh denominator must be exactly the traceable lines"

  test_start "fully_covered_${name}"
  # Every fixture executes all of its own statements, so anything left at
  # zero hits is a line the classifier kept that bash cannot report.
  uncovered="$(lcov_block "$sf" | awk '$2 == 0 {print $1}' | tr '\n' ' ')"
  uncovered="${uncovered% }"
  assert_equals "" "$uncovered" \
    "${name}.sh must reach 100% — uncovered lines are unhittable, not untested"
done

# Note: do NOT add cov_exercise_script here. This test asserts properties of
# the coverage runner itself; running the runner during a coverage run would
# spawn nested traces and pollute the parent's aggregation.

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
