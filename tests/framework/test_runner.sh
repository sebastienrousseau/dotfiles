#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Main test runner for dotfiles test suite
# Discovers and runs all test files, reports results.
#
# Parallelism (closes #867):
#   --jobs N      run N test files concurrently (default: 1)
#   --jobs auto   use the detected CPU count (nproc on Linux,
#                 `sysctl -n hw.ncpu` on macOS)
#
# Per-file output is captured to a private tempfile so concurrent
# runs don't interleave. With --jobs 1, output is streamed live; with
# --jobs >1 it's collected and replayed in completion order.

set -euo pipefail

# Tests import deployed Python scripts from the chezmoi source tree; bytecode
# written there would be deployed by the next chezmoi apply.
export PYTHONDONTWRITEBYTECODE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$TESTS_DIR")"
# Every suite inherits this environment; see git_env.sh.
source "$SCRIPT_DIR/git_env.sh"

if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT is not a valid directory: $REPO_ROOT" >&2
  exit 1
fi

# Export paths for test files
export TESTS_DIR
export REPO_ROOT
export FRAMEWORK_DIR="$SCRIPT_DIR"

# Headless test execution: prevent tests or subprocesses from
# opening GUI windows (browser, text editor, terminal, Finder, notifications) on the host.
export DOT_OPENER=true
export BROWSER=true
export EDITOR=true
export VISUAL=true
export GIT_EDITOR=true
# The shells export the developer's checkout as DOTFILES_DIR, which the
# aliases and scripts prefer to ~/.dotfiles; a test sets its own.
unset DOTFILES_DIR
# zsh reads its startup files from $ZDOTDIR before $HOME, so a developer's
# exported ZDOTDIR loads their real zshrc into every `zsh -i` a test starts,
# whatever HOME the test set. Under the feature matrix, health.sh's
# `zsh -i -c exit` did that and never returned. CI has none.
unset ZDOTDIR

_runner_hermetic_bin="${TMPDIR:-/tmp}/dotfiles-hermetic-bin"
mkdir -p "$_runner_hermetic_bin"
_runner_hermetic_bin="$(cd "$_runner_hermetic_bin" && pwd)"
for _shim in open xdg-open osascript; do
  if [[ ! -x "$_runner_hermetic_bin/$_shim" ]]; then
    printf '#!/bin/sh\nexit 0\n' >"$_runner_hermetic_bin/$_shim"
    chmod +x "$_runner_hermetic_bin/$_shim"
  fi
done
unset _shim

# Hermetic guards: a test must not reach the network or run a real build.
# One that did (a coverage run started `cargo build`, and rustup downloaded
# a toolchain into the sandbox HOME) timed out and wrote into the repo. The
# guard refuses curl/wget to hosts other than loopback, and the build or
# download commands of cargo, rustup and go, with exit 97; read-only probes
# (`go env`, `cargo install --list`) pass through. A test that needs one
# declares it in its first 30 lines: `# test-needs: network go`.
#
# The guards live in a directory of this run's own, removed on exit. Which
# tools get one depends on this run's PATH, and test files start nested
# runners in parallel, so a shared directory let one run delete or restore
# another's guards mid-test. Guards an earlier version left in the shared
# directory are cleared.
rm -f "$_runner_hermetic_bin"/{curl,wget,cargo,rustup,go}
_runner_guard_bin="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-guards.XXXXXX")" && pwd)"
trap 'rm -rf "$_runner_guard_bin"' EXIT
cat >"$_runner_guard_bin/guard" <<'GUARD'
#!/usr/bin/env bash
# Hermetic guard written by tests/framework/test_runner.sh.
tool="${0##*/}"
self_dir="$(cd "${0%/*}" && pwd)"
# The real tool: the first on PATH outside this directory, compared after
# resolving (TMPDIR's trailing slash puts this directory on PATH as `T//…`),
# that is not another run's guard. A nested runner puts its guards ahead of
# the outer run's: each skipping only itself, the two exec'd each other
# forever.
real="" dir=""
IFS=: read -r -a path_dirs <<<"$PATH"
for dir in "${path_dirs[@]}"; do
  [[ -x "$dir/$tool" && "$(cd "$dir" 2>/dev/null && pwd)" != "$self_dir" ]] || continue
  grep -qs '^# Hermetic guard written by tests/framework/test_runner.sh' "$dir/$tool" && continue
  real="$dir/$tool" && break
done
[[ -n "$real" ]] || {
  echo "$tool: command not found" >&2
  exit 127
}
need="$tool" blocked=0
case "$tool" in
  curl | wget)
    need=network
    for arg in "$@"; do
      case "$arg" in
        http://127.0.0.1* | https://127.0.0.1* | http://localhost* | https://localhost* | http://\[::1\]*) ;;
        http://* | https://*) blocked=1 ;;
      esac
    done
    ;;
  cargo) case "${1:-} ${2:-}" in "install --list") ;; build* | install* | run* | test* | fetch* | update* | publish*) blocked=1 ;; esac ;;
  rustup) case "${1:-}" in --version | -V | show | which) ;; *) blocked=1 ;; esac ;;
  go) case "${1:-} ${2:-}" in build* | install* | get* | run* | test* | "mod download"*) blocked=1 ;; esac ;;
esac
case " ${DOT_TEST_NEEDS:-} " in *" $need "*) blocked=0 ;; esac
if [[ "$blocked" -eq 1 ]]; then
  printf 'hermetic: this test ran a real `%s %s`; stub it, or declare `# test-needs: %s` in its header\n' "$tool" "$*" "$need" >&2
  exit 97
fi
exec "$real" "$@"
GUARD
chmod +x "$_runner_guard_bin/guard"
# Guard only the tools that are installed: a guard for a missing tool would
# make `command -v` succeed, and a test that skips without the tool would
# run and fail instead (macOS runners have no go on PATH).
for _shim in curl wget cargo rustup go; do
  if command -v "$_shim" >/dev/null 2>&1; then
    cp "$_runner_guard_bin/guard" "$_runner_guard_bin/$_shim"
  fi
done
rm -f "$_runner_guard_bin/guard"
unset _shim

# The shims, then the guards, first on PATH: an earlier entry would bypass
# them.
_runner_path=":$PATH:"
_runner_path="${_runner_path//:$_runner_hermetic_bin:/:}"
_runner_path="${_runner_path#:}"
export PATH="$_runner_guard_bin:$_runner_hermetic_bin:${_runner_path%:}"
unset _runner_path

# test_needs <test-file>: the tools its `# test-needs:` header line declares.
test_needs() {
  head -n 30 "$1" 2>/dev/null | sed -n 's/^# test-needs: //p' | head -n 1
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

detect_cores() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu 2>/dev/null || echo 1
  else
    echo 1
  fi
}

# Per-file time limit in seconds (0 disables). A hung test file used to
# hold a CI lane until the job's own limit, six hours by default, with
# nothing naming the file. Now it is killed, reported as a timeout, and
# counted as a failure. The slowest suites finish in a few minutes.
TEST_FILE_TIMEOUT="${TEST_FILE_TIMEOUT:-900}"

# run_bounded <seconds> <cmd...>: exit 124 on expiry, the command's own
# status otherwise. perl gives fork + setsid + kill-the-group on both GNU
# and BSD hosts, so a test's stray children die with it (the same
# technique as run_with_timeout in assertions.sh; not sourced here to
# keep the runner self-contained). Without perl the limit is not
# enforced.
run_bounded() {
  local secs="$1"
  shift
  if [[ "$secs" -le 0 ]] || ! command -v perl >/dev/null 2>&1; then
    "$@"
    return $?
  fi
  perl -e '
    use POSIX qw(setsid);
    my $secs = shift @ARGV;
    my $pid  = fork();
    die "run_bounded: fork failed: $!\n" unless defined $pid;
    if ($pid == 0) {
      setsid();
      exec { $ARGV[0] } @ARGV;
      exit 127;
    }
    my $timed_out = 0;
    $SIG{ALRM} = sub { $timed_out = 1; kill("KILL", -$pid); };
    alarm($secs);
    my $reaped;
    do { $reaped = waitpid($pid, 0); } while ($reaped == -1 && $!{EINTR});
    my $status = $?;
    alarm(0);
    kill("KILL", -$pid);
    exit(124) if $timed_out;
    exit($status & 127 ? 128 + ($status & 127) : $status >> 8);
  ' "$secs" "$@"
}

# Describe a non-zero exit for the failure list and the log line.
describe_exit() {
  if [[ "$1" -eq 124 ]]; then
    printf 'timed out after %ss' "$TEST_FILE_TIMEOUT"
  else
    printf 'crashed exit=%s' "$1"
  fi
}

# Run a single test file in serial mode (live output).
run_test_file_serial() {
  local test_file="$1"
  local temp_results
  temp_results=$(mktemp)
  # Double-quote: $temp_results captured at trap-registration time, so
  # the trap fires correctly even when run from a calling function that
  # has `set -u` enabled.
  # shellcheck disable=SC2064
  trap "rm -f '$temp_results'" RETURN

  echo ""
  echo "Running: $(basename "$test_file")"
  echo "─────────────────────────────────────"

  local exit_status=0
  DOT_TEST_NEEDS="$(test_needs "$test_file")" run_bounded "$TEST_FILE_TIMEOUT" bash "$test_file" </dev/null 2>&1 | tee "$temp_results" || exit_status=$?

  local results_line
  results_line=$(grep "^RESULTS:" "$temp_results" | tail -1) || true
  if [[ -n "$results_line" ]]; then
    local run passed failed
    IFS=':' read -r _ run passed failed <<<"$results_line"
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + passed))
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + passed + failed))
    if [[ "$failed" -gt 0 ]]; then record_failure "$(basename "$test_file")" "$failed" "$failed failed"; fi
  elif [[ $exit_status -ne 0 ]]; then
    printf '%b\n' "\033[0;31mERROR: $(basename "$test_file") $(describe_exit "$exit_status") without producing results\033[0m"
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + 1))
    record_failure "$(basename "$test_file")" 1 "$(describe_exit "$exit_status")"
  fi
}

# Quarantine (tests/quarantine.tsv, checked by tools/ci/check-quarantine.py):
# a listed file still runs and its failures are still printed, but until the
# entry's expiry date they do not fail the run.
QUARANTINE_FILE="${QUARANTINE_FILE:-$TESTS_DIR/quarantine.tsv}"

# is_quarantined <file-basename>: true when an unexpired entry lists the file.
is_quarantined() {
  [[ -f "$QUARANTINE_FILE" ]] || return 1
  awk -F'\t' -v name="$1" -v today="$(date +%Y-%m-%d)" \
    '$0 !~ /^#/ && $1 == name && $3 >= today { found = 1 } END { exit !found }' "$QUARANTINE_FILE"
}

# record_failure <file-basename> <count> <label>: count a failing file, or
# list it as quarantined when is_quarantined says so.
record_failure() {
  if is_quarantined "$1"; then
    QUARANTINED_FILES+=("$1 ($3)")
  else
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + $2))
    TOTAL_FAILED_FILES+=("$1 ($3)")
  fi
}

# Worker for parallel mode: write per-file output to its own file.
# Invoked via xargs -I {} so it receives one filename per invocation.
run_test_file_worker() {
  local test_file="$1"
  local out_dir="$2"
  local out_file="$out_dir/$(basename "$test_file").out"

  {
    echo ""
    echo "Running: $(basename "$test_file")"
    echo "─────────────────────────────────────"
    local exit_status=0
    DOT_TEST_NEEDS="$(test_needs "$test_file")" run_bounded "$TEST_FILE_TIMEOUT" bash "$test_file" </dev/null 2>&1 || exit_status=$?
    # Append exit status sentinel for the aggregator
    printf 'EXIT_STATUS:%d\n' "$exit_status"
  } >"$out_file" 2>&1
}

# Aggregate per-file outputs (for parallel mode), replay them in
# alphabetical order, and tally results.
aggregate_parallel_results() {
  local out_dir="$1"
  local f

  for f in "$out_dir"/*.out; do
    [[ -f "$f" ]] || continue
    cat "$f"

    local results_line exit_status_line exit_status=0
    results_line=$(grep "^RESULTS:" "$f" | tail -1) || true
    exit_status_line=$(grep "^EXIT_STATUS:" "$f" | tail -1) || true
    if [[ -n "$exit_status_line" ]]; then
      exit_status=${exit_status_line#EXIT_STATUS:}
    fi

    if [[ -n "$results_line" ]]; then
      local run passed failed
      IFS=':' read -r _ run passed failed <<<"$results_line"
      TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + passed))
      TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + passed + failed))
      if [[ "$failed" -gt 0 ]]; then record_failure "$(basename "$f" .out)" "$failed" "$failed failed"; fi
    elif [[ $exit_status -ne 0 ]]; then
      printf '%b\n' "\033[0;31mERROR: $(basename "$f" .out) $(describe_exit "$exit_status") without producing results\033[0m"
      TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + 1))
      record_failure "$(basename "$f" .out)" 1 "$(describe_exit "$exit_status")"
    fi
  done
}

# is_quiet_lane <file> - true when the file's header (first 20 lines) carries
# `# test-lane: quiet`. Such a file times something against a wall-clock
# budget (tests/regression/test_gate_integrity.sh runs the real perf gate),
# so in parallel mode it runs on its own after the pool has drained: inside
# the pool the rest of the suite loads the machine past what it measures.
is_quiet_lane() {
  head -n 20 "$1" 2>/dev/null | grep -q '^# test-lane: quiet$'
}

# Run test files in parallel ($JOBS workers), then the quiet lane one file
# at a time, then the framework invariants, which read the others' results.
# Args: <test-file...>
run_test_list_parallel() {
  local out_dir
  out_dir=$(mktemp -d)
  # shellcheck disable=SC2064  # capture $out_dir at trap-registration time
  trap "rm -rf '$out_dir'" RETURN

  export -f run_test_file_worker run_bounded describe_exit test_needs
  export TEST_FILE_TIMEOUT
  local -a primary_files=() quiet_files=() deferred_inv=()
  local f
  for f in "$@"; do
    if [[ "$(basename "$f")" == "test_test_framework_invariants.sh" ]]; then
      deferred_inv+=("$f")
    elif is_quiet_lane "$f"; then
      quiet_files+=("$f")
    else
      primary_files+=("$f")
    fi
  done

  if [[ ${#primary_files[@]} -gt 0 ]]; then
    # shellcheck disable=SC2016  # $0 inside xargs invocation
    printf '%s\n' "${primary_files[@]}" | xargs -I{} -P "$JOBS" \
      bash -c 'run_test_file_worker "$@"' _ {} "$out_dir"
  fi
  for f in ${quiet_files[@]+"${quiet_files[@]}"}; do
    run_test_file_worker "$f" "$out_dir"
  done
  for f in ${deferred_inv[@]+"${deferred_inv[@]}"}; do
    INVARIANT_RESULTS_DIR="$out_dir" run_test_file_worker "$f" "$out_dir"
  done

  aggregate_parallel_results "$out_dir"
}

# Run a list of test files. Honours $JOBS (set by main).
# Args: <header-text> <test-file...>
run_test_list() {
  local header="$1"
  shift
  [[ $# -eq 0 ]] && return 0

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$header"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$JOBS" -le 1 ]]; then
    local f
    for f in "$@"; do
      run_test_file_serial "$f"
    done
  else
    run_test_list_parallel "$@"
  fi
}

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Dotfiles Test Runner

Usage:
  $(basename "$0") [options] [pattern]

Options:
  -h, --help          Show this help message
  -v, --verbose       Verbose output
  -i, --integration   Include integration tests
  --integration-only  Run integration tests without repeating unit/regression tests
  -u, --unit-only     Run only unit tests
  --jobs N            Run N test files in parallel (default 1)
  --jobs auto         Use the detected CPU count

Arguments:
  pattern             Run only tests matching pattern (e.g., 'extract', 'backup')

Examples:
  $(basename "$0")                    # Run all unit tests serially
  $(basename "$0") --jobs auto        # Run all unit tests in parallel
  $(basename "$0") extract            # Run only extract tests
  $(basename "$0") -i                 # Run unit and integration tests
  $(basename "$0") --integration-only # Run only integration tests
  RUN_INTEGRATION=1 $(basename "$0")  # Alternative way to run integration tests

Environment Variables:
  RUN_INTEGRATION=1   Enable integration tests
  VERBOSE=1           Enable verbose output
  TEST_JOBS=N         Default parallelism (overridden by --jobs)
  TEST_FILE_TIMEOUT=S Kill a test file after S seconds (default 900, 0 = off)
EOF
}

main() {
  local test_pattern="*"
  local run_integration="${RUN_INTEGRATION:-0}"
  local verbose="${VERBOSE:-0}"
  local unit_only=0
  local integration_only=0
  JOBS="${TEST_JOBS:-1}"

  TOTAL_TESTS_RUN=0
  TOTAL_TESTS_PASSED=0
  TOTAL_TESTS_FAILED=0
  TOTAL_FAILED_FILES=()
  QUARANTINED_FILES=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        verbose=1
        shift
        ;;
      -i | --integration)
        run_integration=1
        shift
        ;;
      --integration-only)
        run_integration=1
        integration_only=1
        shift
        ;;
      -u | --unit-only)
        unit_only=1
        shift
        ;;
      --jobs)
        shift
        case "${1:-}" in
          auto) JOBS=$(detect_cores) ;;
          [0-9]*) JOBS="$1" ;;
          *)
            echo "Error: --jobs requires a positive integer or 'auto'" >&2
            exit 1
            ;;
        esac
        shift
        ;;
      --jobs=*)
        case "${1#*=}" in
          auto) JOBS=$(detect_cores) ;;
          [0-9]*) JOBS="${1#*=}" ;;
          *)
            echo "Error: --jobs requires a positive integer or 'auto'" >&2
            exit 1
            ;;
        esac
        shift
        ;;
      -*)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
      *)
        test_pattern="$1"
        shift
        ;;
    esac
  done

  echo "╔═══════════════════════════════════════╗"
  echo "║     Dotfiles Test Suite               ║"
  echo "╚═══════════════════════════════════════╝"
  echo ""
  echo "Repository: $REPO_ROOT"
  echo "Tests Dir:  $TESTS_DIR"
  echo "Parallelism: $JOBS"
  echo ""

  if [[ "$integration_only" != "1" ]]; then
    # Collect unit tests
    local unit_files=()
    while IFS= read -r -d '' f; do
      unit_files+=("$f")
    done < <(find "$TESTS_DIR"/unit -name "test_${test_pattern}.sh" -type f -print0 | sort -z)

    if [[ ${#unit_files[@]} -eq 0 ]]; then
      echo "No unit tests found matching pattern: $test_pattern"
      # A narrowed run that selects nothing tested nothing; passing it hid
      # a CI step whose glob pointed where no test lived.
      [[ "$test_pattern" == "*" ]] || exit 1
    else
      run_test_list "UNIT TESTS (${#unit_files[@]} files)" "${unit_files[@]}"
    fi
  fi

  # Collect + run regression tests. These are always run alongside unit
  # tests (issue #868 — regressions must always be exercised), but only
  # when the user is running the full suite. When a `pattern` argument
  # narrows the unit set (e.g. `--jobs 1 secrets_*` from
  # test_runner_parallel_invariant.sh), skip regression tests to avoid
  # recursive self-invocation through the parallel-invariant guard.
  if [[ "$unit_only" != "1" && "$integration_only" != "1" && "$test_pattern" == "*" ]]; then
    local regression_files=()
    while IFS= read -r -d '' f; do
      regression_files+=("$f")
    done < <(find "$TESTS_DIR"/regression -name "test_*.sh" -type f -print0 | sort -z)
    if [[ ${#regression_files[@]} -gt 0 ]]; then
      run_test_list "REGRESSION TESTS (${#regression_files[@]} files)" "${regression_files[@]}"
    fi
  fi

  # Collect + run integration tests if requested. Same pattern-gate
  # as the regression block above: when a `pattern` narrows the unit
  # set (e.g. `--jobs auto secrets_*` from
  # test_runner_parallel_invariant.sh), skip integration tests too.
  # Without this gate the inner parallel run pulls in every
  # integration test whenever RUN_INTEGRATION was inherited from the
  # outer reliability-audit --with-integration invocation, which
  # turned into a flaky chezmoi-apply assertion on macOS Reliability.
  if [[ "$run_integration" == "1" && "$unit_only" != "1" && "$test_pattern" == "*" ]]; then
    local integration_files=()
    for f in "$TESTS_DIR"/integration/test_*.sh; do
      [[ -f "$f" ]] && integration_files+=("$f")
    done
    if [[ ${#integration_files[@]} -gt 0 ]]; then
      run_test_list "INTEGRATION TESTS (${#integration_files[@]} files)" "${integration_files[@]}"
    else
      echo "No integration tests found."
    fi
  fi

  # Final summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "FINAL SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf '%b\n' "Total tests run: $TOTAL_TESTS_RUN"
  printf '%b\n' "\033[0;32mTotal passed: $TOTAL_TESTS_PASSED\033[0m"
  printf '%b\n' "\033[0;31mTotal failed: $TOTAL_TESTS_FAILED\033[0m"
  if [[ "${#TOTAL_FAILED_FILES[@]}" -gt 0 ]]; then
    printf '%b\n' "\033[0;31mFailed test files (${#TOTAL_FAILED_FILES[@]}):\033[0m"
    printf '  - %s\n' "${TOTAL_FAILED_FILES[@]}"
  fi
  if [[ "${#QUARANTINED_FILES[@]}" -gt 0 ]]; then
    printf '%b\n' "\033[0;33mQuarantined test files (${#QUARANTINED_FILES[@]}):\033[0m"
    printf '  - %s\n' "${QUARANTINED_FILES[@]}"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ $TOTAL_TESTS_FAILED -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
