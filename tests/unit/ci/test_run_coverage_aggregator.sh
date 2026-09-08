#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
EXPECT_subst="2 6 7 11 12 15 16 19 20 23 24 25 29 32"

# Continuations: plain backslash-joined words (untraceable) versus a
# continuation that starts a new command (traced at its own line), plus a
# multi-line double-quoted string.
#
# Lines 6 and 8 — the heads of `true \` / `&& …` and `false \` / `|| …` —
# are deliberately absent from the expectation. bash 5.3 traces them at
# their own line; bash 5.2 (every current Linux runner) traces them at the
# operator line instead, leaving them permanently unhittable there. The
# classifier drops them so the denominator is the same on both.
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
EXPECT_contin="2 7 9 10 11 12 15 16 17"

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

# Driven with its stderr captured AND discarded — the pattern that used to
# throw a child's whole contribution away, because xtrace writes to fd 2.
cat >"$SANDBOX/src/captured.sh" <<'FIXTURE'
#!/usr/bin/env bash
emit() {
  echo "captured-stdout"
  echo "captured-stderr" >&2
}
emit
echo "captured-done"
FIXTURE
EXPECT_captured="3 4 6 7"

FIXTURES="funcs cases subst contin terminators plain captured"

# Driver: runs every fixture so that all of their statements execute.
{
  echo '#!/usr/bin/env bash'
  echo '# SPDX-License-Identifier: MIT'
  echo 'SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../src" && pwd)"'
  for name in $FIXTURES; do
    if [[ "$name" == "captured" ]]; then
      echo "bash \"\$SRC/${name}.sh\" >/dev/null 2>&1 || true"
    else
      echo "bash \"\$SRC/${name}.sh\" >/dev/null || true"
    fi
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

# Which bash will actually drive the traced children decides whether the
# dedicated xtrace descriptor is available at all (BASH_XTRACEFD is 4.1+).
DRIVER_BASH_VERSION="$(bash -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"' 2>/dev/null || echo "0.0")"
DRIVER_BASH_HAS_XTRACEFD=0
case "$DRIVER_BASH_VERSION" in
  0.* | 1.* | 2.* | 3.* | 4.0) : ;;
  *) DRIVER_BASH_HAS_XTRACEFD=1 ;;
esac

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
  #
  # captured.sh is the exception: it is driven with `>/dev/null 2>&1`, and
  # only BASH_XTRACEFD keeps its records out of that redirection. On a
  # bash older than 4.1 — /bin/bash on macOS, which is what `bash`
  # resolves to on a stock macOS runner — there is no such descriptor and
  # the records genuinely are lost. That is a documented limitation of the
  # mechanism on bash 3.x, not a classifier defect, so record a skip
  # rather than a failure the fixture cannot control.
  if [[ "$name" == "captured" ]] && [[ "$DRIVER_BASH_HAS_XTRACEFD" != "1" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (bash ${DRIVER_BASH_VERSION} has no BASH_XTRACEFD)"
    continue
  fi
  uncovered="$(lcov_block "$sf" | awk '$2 == 0 {print $1}' | tr '\n' ' ')"
  uncovered="${uncovered% }"
  assert_equals "" "$uncovered" \
    "${name}.sh must reach 100% — uncovered lines are unhittable, not untested"
done

# -----------------------------------------------------------------------------
# The runner must refuse to report a number when a test was killed.
# -----------------------------------------------------------------------------
test_start "timeout_kill_is_a_hard_error"
mkdir -p "$SANDBOX/tests-hang/unit" "$SANDBOX/tests-hang/regression"
cat >"$SANDBOX/tests-hang/unit/test_hangs.sh" <<'EOF'
#!/usr/bin/env bash
sleep 60
EOF
cat >"$SANDBOX/tests-hang/unit/test_quick.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULTS:1:1:0"
EOF
set +e
env REPO_ROOT="$SANDBOX" \
  TESTS_DIR="$SANDBOX/tests-hang" \
  COVERAGE_DIR="$SANDBOX/coverage2" \
  COVERAGE_OUT="$SANDBOX/coverage2/lcov.info" \
  COV_INCLUDE_DIRS="$SANDBOX/src" \
  MIN_COVERAGE_PCT=0 \
  COV_TEST_TIMEOUT=2 \
  JOBS=2 \
  bash "$RUNNER" >"$SANDBOX/runner-timeout.log" 2>&1
timeout_ec=$?
if [[ "$timeout_ec" -ne 0 ]] &&
  grep -q "killed by coverage timeout: unit/test_hangs.sh" "$SANDBOX/runner-timeout.log"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected non-zero exit naming the killed test (got $timeout_ec)"
fi

test_start "policy_skip_is_explicit_and_announced"
# The escape hatch for a test that no budget can fit is an explicit,
# printed list — never a silent kill.
set +e
env REPO_ROOT="$SANDBOX" \
  TESTS_DIR="$SANDBOX/tests-hang" \
  COVERAGE_DIR="$SANDBOX/coverage3" \
  COVERAGE_OUT="$SANDBOX/coverage3/lcov.info" \
  COV_INCLUDE_DIRS="$SANDBOX/src" \
  MIN_COVERAGE_PCT=0 \
  COV_TEST_TIMEOUT=2 \
  COV_SKIP_TESTS="unit/test_hangs.sh:unit/test_other.sh" \
  JOBS=2 \
  bash "$RUNNER" >"$SANDBOX/runner-skip.log" 2>&1
skip_ec=$?
rm -rf "$SANDBOX/tests-hang"
if [[ "$skip_ec" -eq 0 ]] &&
  grep -q "skipped-by-policy: 1 test(s): unit/test_hangs.sh" "$SANDBOX/runner-skip.log" &&
  grep -q "killed-by-timeout: 0 test(s)" "$SANDBOX/runner-skip.log"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected a clean run naming the skipped test (got $skip_ec)"
fi

test_start "trace_records_survive_a_long_path_under_bash32"
# macOS /bin/bash is 3.2 and truncates the expanded PS4 at 100 characters.
# The runner's record format must stay short enough that a deep checkout
# cannot cut the `:@` terminator off and make the record unparsable.
if [[ -x /bin/bash ]] && /bin/bash --version 2>/dev/null | head -1 | grep -q 'version 3\.'; then
  deep="$SANDBOX/aaaaaaaaaa/bbbbbbbbbb/cccccccccc/dddddddddd/eeeeeeeeee/ffffffffff"
  mkdir -p "$deep"
  printf '#!/usr/bin/env bash\necho deep\n' >"$deep/deep.sh"
  cov_ps4="$(grep -m1 '^COV_PS4=' "$RUNNER" | cut -d= -f2- | sed "s/^'//; s/'$//")"
  deep_trace="$SANDBOX/deep.trace"
  COV_ROOT="$SANDBOX" PS4="$cov_ps4" /bin/bash -xu "$deep/deep.sh" \
    2>"$deep_trace" >/dev/null || true
  intact="$(grep -cE '^\+@COV@:[0-9]+:[^:]*:@' "$deep_trace" 2>/dev/null)" || intact=0
  allrec="$(grep -cE '^\++@COV@:[0-9]+:' "$deep_trace" 2>/dev/null)" || allrec=0
  if [[ "$intact" -gt 0 && "$intact" -eq "$allrec" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${intact}/${allrec} records intact from a ${#deep} char path"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (no bash 3.x at /bin/bash)"
fi

test_start "silent_trace_is_reported"
# A test whose stderr goes nowhere yields an empty trace while exiting 0.
# That must be named, not absorbed.
mkdir -p "$SANDBOX/tests-silent/unit" "$SANDBOX/tests-silent/regression"
cat >"$SANDBOX/tests-silent/unit/test_silent.sh" <<'EOF'
#!/usr/bin/env bash
# Synthetic stand-in for the real shape of this failure: a suite whose
# stderr is redirected away on a shell too old for BASH_XTRACEFD, so the
# runner is handed an empty trace and a clean exit status. Pointing
# BASH_XTRACEFD at the discarded descriptor and clearing what was written
# before that reproduces the same end state on a modern bash.
exec 2>/dev/null
BASH_XTRACEFD=2
: >"${COV_TRACE_FILE:-/dev/null}"
echo "RESULTS:1:1:0"
EOF
set +e
env REPO_ROOT="$SANDBOX" \
  TESTS_DIR="$SANDBOX/tests-silent" \
  COVERAGE_DIR="$SANDBOX/coverage4" \
  COVERAGE_OUT="$SANDBOX/coverage4/lcov.info" \
  COV_INCLUDE_DIRS="$SANDBOX/src" \
  MIN_COVERAGE_PCT=0 \
  JOBS=2 \
  bash "$RUNNER" >"$SANDBOX/runner-silent.log" 2>&1
silent_ec=$?
rm -rf "$SANDBOX/tests-silent"
if grep -q "no coverage captured from: unit/test_silent.sh" "$SANDBOX/runner-silent.log" &&
  grep -q "silent-traces: 1 test(s)" "$SANDBOX/runner-silent.log"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: runner did not name the silent test (exit $silent_ec)"
fi

test_start "empty_bash_source_is_not_mistaken_for_truncation"
# `bash -c` has no BASH_SOURCE[0], so records legitimately carry an empty
# file field. Those must parse (and then be skipped for having no file),
# not be counted as mangled — otherwise the truncation audit cries wolf on
# every run and the real signal is lost in the noise.
assert_file_contains "$RUNNER" 'hit_re = re.compile(r"^\++@COV@:(\d+):([^:]*):@")' \
  "the record pattern must accept an empty BASH_SOURCE field"

test_start "incomplete_sweep_is_a_hard_error"
# A worker that dies before recording a status leaves the sweep short, and
# `xargs … || true` hides it. The runner must refuse to report a
# percentage computed from a fraction of the suite.
#
# The fixture has to find its grandparent to kill it; without /proc or
# `ps` there is no portable way, so record a skip rather than a false
# failure (a slim container is the case that hits this).
if [[ ! -r /proc/self/stat ]] && ! command -v ps >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (no /proc and no ps to find the worker)"
else
  mkdir -p "$SANDBOX/tests-partial/unit" "$SANDBOX/tests-partial/regression"
  printf '#!/usr/bin/env bash\necho "RESULTS:1:1:0"\n' \
    >"$SANDBOX/tests-partial/unit/test_ok.sh"
  cat >"$SANDBOX/tests-partial/unit/test_kills_its_worker.sh" <<'EOF'
#!/usr/bin/env bash
# Kill the xargs worker two levels up (this shell <- timeout <- worker),
# reproducing "xargs: bash: terminated with signal 15": the worker dies
# before it can record a status, so this test leaves no result behind.
# /proc first (Linux, and present even in images without procps), `ps`
# second (macOS and anything else).
worker=""
if [[ -r "/proc/$PPID/stat" ]]; then
  worker="$(awk '{print $4}' "/proc/$PPID/stat" 2>/dev/null)"
fi
if [[ -z "$worker" ]] && command -v ps >/dev/null 2>&1; then
  worker="$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ')"
fi
[[ -n "$worker" && "$worker" != "0" ]] && kill -TERM "$worker" 2>/dev/null
sleep 5
EOF
  set +e
  env REPO_ROOT="$SANDBOX" \
    TESTS_DIR="$SANDBOX/tests-partial" \
    COVERAGE_DIR="$SANDBOX/coverage5" \
    COVERAGE_OUT="$SANDBOX/coverage5/lcov.info" \
    COV_INCLUDE_DIRS="$SANDBOX/src" \
    MIN_COVERAGE_PCT=0 \
    COV_TEST_TIMEOUT=30 \
    JOBS=1 \
    bash "$RUNNER" >"$SANDBOX/runner-partial.log" 2>&1
  partial_ec=$?
  rm -rf "$SANDBOX/tests-partial"
  if [[ "$partial_ec" -ne 0 ]] &&
    grep -qE "tests-completed: [01]/2" "$SANDBOX/runner-partial.log" &&
    grep -q "no result recorded for: unit/test_kills_its_worker.sh" "$SANDBOX/runner-partial.log"; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected a non-zero exit naming the test with no result (got $partial_ec)"
    grep -E 'tests-completed|no result' "$SANDBOX/runner-partial.log" >&2 || true
  fi
fi

test_start "xtrace_uses_a_dedicated_descriptor"
assert_file_contains "$RUNNER" "BASH_XTRACEFD=" \
  "xtrace must not be written to fd 2, where a test's redirection can eat it"

test_start "truncated_records_are_audited"
assert_file_contains "$RUNNER" "truncated-trace-records:" \
  "a record that lost its terminator must be counted and reported"

test_start "timeout_default_is_documented"
assert_file_contains "$RUNNER" 'COV_TEST_TIMEOUT:-300' \
  "the per-test budget must stay above the slowest real suite"

test_start "killed_tests_are_summarised"
assert_file_contains "$RUNNER" "killed-by-timeout:" \
  "the runner must print a summary line naming any killed file"

# Note: do NOT add cov_exercise_script here. This test asserts properties of
# the coverage runner itself; running the runner during a coverage run would
# spawn nested traces and pollute the parent's aggregation.

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
