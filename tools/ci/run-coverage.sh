#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# run-coverage.sh — Bash code-coverage runner using pure xtrace
# instrumentation. Emits lcov.info at $COVERAGE_OUT.
#
# Why pure xtrace (not kcov):
#   kcov v43 on Ubuntu 24.04 + bash 5.2 won't emit bash-script
#   coverage in either mode: without bash-dbgsym it captures nothing,
#   and with bash-dbgsym it captures bash's *C-binary* internals
#   (ctype.h, stdio.h) instead of the .sh file lines we care about.
#   We bypass kcov entirely by using bash's own xtrace mechanism:
#
#     PS4='+:${LINENO}:${BASH_SOURCE}:'   # encode line + file in trace
#     BASH_ENV=/setup-that-runs-set-x      # turn on xtrace in every
#                                          # non-interactive bash, so
#                                          # children inherit tracing
#     bash test.sh 2>traces/test.trace     # capture lines per test
#
#   Then we parse all traces with regex and write lcov.info. This is
#   the same mechanism bashcov uses, minus the Ruby runtime.
#
# Linux + macOS both work. macOS is the awkward one: /bin/bash is 3.2,
# which truncates the expanded PS4 at 100 characters, so the record
# format below stays short on purpose and the startup probe refuses to
# run if a reachable bash mangles records anyway. The pre-commit hook in
# this repo can invoke this on any platform.
#
# Closes the runner half of #856 / Slice 1 of #883.
# =============================================================================

set -uo pipefail

# The trace record format (see _cov_write_bash_env). Defined before anything
# else so `--print-ps4` can report it without side effects.
COV_PS4='+@COV@:${LINENO}:${BASH_SOURCE[0]:+${BASH_SOURCE[0]#${COV_ROOT:-__cov_unset__}/}}:@ '
if [[ "${1:-}" == --print-ps4 ]]; then
  printf '%s\n' "$COV_PS4"
  exit 0
fi

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TESTS_DIR="${TESTS_DIR:-$REPO_ROOT/tests}"
COVERAGE_DIR="${COVERAGE_DIR:-$REPO_ROOT/coverage}"
COVERAGE_OUT="${COVERAGE_OUT:-$COVERAGE_DIR/lcov.info}"
MIN_COVERAGE_PCT="${MIN_COVERAGE_PCT:-0}" # initial floor; tighten per slice
COV_INCLUDE_DIRS="${COV_INCLUDE_DIRS:-$REPO_ROOT/scripts:$REPO_ROOT/lib:$REPO_ROOT/defaults/dot_local/bin:$REPO_ROOT/defaults/.chezmoitemplates/functions}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
# Per-test wall-clock budget.
#
# This used to be 60s, which was *below* the real cost of the heavier
# suites once they run under xtrace with the sweep's own parallelism
# competing for CPU (test_auto_doctor.sh, test_auto_verify.sh,
# test_version_sync_exec.sh and ~25 others). Those tests were SIGTERMed
# mid-run and contributed nothing to the denominator's numerator, so the
# reported percentage silently tracked machine load: the same tree
# measured twice could differ by whole points and individual files could
# appear to lose coverage between runs that never touched them.
#
# 300s is ~2x the slowest test measured over a full sweep at `JOBS=3` on
# a contended 10-core laptop: regression/test_dot_help_flag_universal.sh
# at 157s, unit/auto/test_auto_dot_driver.sh at 112s. The one test that
# came closer, unit/theme/test_themes_toml.sh at 273s, is slow only on a
# developer machine — it runs `magick identify` over the user's real
# ~/Pictures/Wallpapers library, which does not exist on a CI runner.
# It is still a real hang-guard — a genuinely blocked test dies in five
# minutes rather than stalling the sweep — but it no longer truncates
# tests that are merely slow.
#
# Regardless of the value, a kill is now a HARD ERROR (see the
# post-sweep audit below): a silent kill that moves the number is the
# one outcome this runner must never produce again.
COV_TEST_TIMEOUT="${COV_TEST_TIMEOUT:-300}"

# Tests deliberately not traced, as paths relative to $TESTS_DIR,
# colon-separated. This is an EXPLICIT list, printed on every run — the
# opposite of the silent timeout kill it replaces.
#
#   regression/test_test_framework_invariants.sh is a meta-suite: it runs
#   every OTHER regression suite serially, each with its own 180s inner
#   budget, so its wall-clock cost is the sum of the entire regression
#   tier and no per-test budget can accommodate it. Every suite it invokes
#   is already traced directly by this sweep: re-aggregating a full sweep
#   with and without its trace gives the identical 7700/10977 lines, so
#   excluding it removes a duplicate, not coverage.
COV_SKIP_TESTS="${COV_SKIP_TESTS:-regression/test_test_framework_invariants.sh}"

# GNU `timeout` guards against a hung test stalling the sweep, but it does
# not exist on stock macOS (it's coreutils). Prefer `timeout`, then
# `gtimeout` (brew coreutils), then a Perl alarm fallback available on
# stock macOS. Without a wrapper, a single blocking traced test can stall
# the entire sweep.
if [[ "${COV_TIMEOUT_CMD+x}" != "x" ]]; then
  COV_TIMEOUT_CMD=""
  if command -v timeout >/dev/null 2>&1; then
    COV_TIMEOUT_CMD="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    COV_TIMEOUT_CMD="gtimeout"
  elif command -v perl >/dev/null 2>&1; then
    COV_TIMEOUT_CMD="_cov_perl_timeout"
  fi
fi

# shellcheck disable=SC2317  # exported for indirect worker invocation
_cov_perl_timeout() {
  local kill_after=5
  if [[ "${1:-}" == --kill-after=* ]]; then
    kill_after="${1#--kill-after=}"
    shift
  fi
  local seconds="${1:-60}"
  shift || true
  perl -e '
    my $seconds = shift @ARGV;
    my $kill_after = shift @ARGV;
    my $pid = fork();
    if (!defined $pid) { exit 127; }
    if ($pid == 0) {
      setpgrp(0, 0);
      exec @ARGV;
      exit 127;
    }
    $SIG{ALRM} = sub {
      kill "TERM", -$pid;
      sleep $kill_after;
      kill "KILL", -$pid;
      waitpid($pid, 0);
      exit 124;
    };
    alarm $seconds;
    waitpid($pid, 0);
    my $status = $?;
    alarm 0;
    if ($status == -1) { exit 127; }
    if ($status & 127) { exit 128 + ($status & 127); }
    exit($status >> 8);
  ' "$seconds" "$kill_after" "$@"
}

_cov_setup_dirs() {
  mkdir -p "$COVERAGE_DIR"
  trace_dir="$COVERAGE_DIR/traces"
  rm -rf "$trace_dir"
  mkdir -p "$trace_dir"
  status_dir="$COVERAGE_DIR/status"
  rm -rf "$status_dir"
  mkdir -p "$status_dir"
}

# -----------------------------------------------------------------------------
# The trace record format.
#
# Two properties matter and neither is negotiable:
#
#   1. `${BASH_SOURCE[0]:+…}` (not `${BASH_SOURCE}`) keeps PS4 evaluation
#      from failing under `set -u`: at the top level of a `bash -c`
#      script BASH_SOURCE[0] is unbound, and an unguarded expansion
#      aborts the shell, taking out any test that sources a
#      `set -euo pipefail` library file. The `:+` form neither errors on
#      an unset variable nor expands its body when unset, so it survives
#      `set -u` while still allowing the prefix strip below.
#
#   2. The path is emitted RELATIVE to the repo root. bash 3.2 — still
#      /bin/bash on macOS, and reachable from any test whose PATH farm
#      resolves `bash` there — truncates the expanded PS4 at 100
#      characters. A checkout path long enough to push the `:@`
#      terminator past that limit mangles every record from such a
#      child, and the aggregator drops them: measured coverage would
#      depend on how deep the checkout happens to sit. A repo-relative
#      path keeps the prefix around 45 characters whatever the checkout
#      path. `COV_ROOT` is exported for the strip; if a sandbox scrubs
#      it the pattern cannot match and the record falls back to the
#      absolute path (still correct, just long), which the truncation
#      audit after aggregation then catches.
# -----------------------------------------------------------------------------
# BASH_ENV setup file: enables xtrace in every non-interactive bash that
# inherits it. Child processes spawned via `bash $SCRIPT` get their own
# tracing turned on automatically.
_cov_write_bash_env() {
  export COV_ROOT="$REPO_ROOT"
  bash_env="$COVERAGE_DIR/_cov_bashenv.sh"
  : >"$bash_env"
  printf "PS4='%s'\n" "$COV_PS4" >>"$bash_env"
  cat >>"$bash_env" <<'SETUP'
# Route xtrace to a descriptor of our own instead of stderr.
#
# This is the difference between measuring a child and losing it. A test
# that captures or discards a child's stderr — `out=$(cmd 2>&1)`,
# `cmd 2>/dev/null`, `cmd &>/dev/null`, `cmd |& …` — takes that child's
# xtrace records with it, because they are written to fd 2. The child
# runs, does its work, and contributes nothing: one such line in one test
# file was measuring scripts/dot/commands/registry.sh at 58% when it was
# really at 75%. The runner cannot police what a test redirects, but it
# can put the records somewhere a redirection cannot reach.
#
# BASH_XTRACEFD is bash 4.1+. Older shells (macOS /bin/bash 3.2) fall
# through and keep writing to stderr, which the worker redirects to the
# same file — the pre-existing behaviour, no worse. The `exec` sits
# inside `eval` because bash 3.2 cannot even *parse* `{var}>`, and
# BASH_ENV files are parsed whole before anything runs.
if [ -n "${COV_TRACE_FILE:-}" ] && [ -z "${BASH_XTRACEFD:-}" ]; then
  case "${BASH_VERSION:-}" in
    1.* | 2.* | 3.* | 4.0*) : ;;
    *)
      if eval 'exec {__cov_xfd}>>"$COV_TRACE_FILE"' 2>/dev/null; then
        BASH_XTRACEFD=$__cov_xfd
      fi
      ;;
  esac
fi
# Enabled last so the plumbing above does not trace itself.
set -x
SETUP
}

# _cov_probe_one <bash>: run the probe target through <bash>; exits 2 when
# its records are missing or mangled.
_cov_probe_one() {
  local probe_bash="$1" probe_trace probe_lines probe_all probe_bad probe_version
  probe_trace="$trace_dir/_probe.trace"
  : >"$probe_trace"
  PS4="$COV_PS4" \
    BASH_ENV="$bash_env" \
    COV_TRACE_FILE="$probe_trace" \
    "$probe_bash" "$probe_target" 2>"$probe_trace" >/dev/null </dev/null || true
  probe_lines=$(grep -cE '^\+@COV@:[0-9]+:[^:]*:@' "$probe_trace" 2>/dev/null) || probe_lines=0
  probe_all=$(grep -cE '^\++@COV@:[0-9]+:' "$probe_trace" 2>/dev/null) || probe_all=0
  probe_bad=$((probe_all - probe_lines))
  probe_version=$("$probe_bash" -c 'echo "${BASH_VERSION%%(*}"' 2>/dev/null || echo "?")
  echo "probe: ${probe_bash} (bash ${probe_version}) — ${probe_lines} intact record(s), ${probe_bad} mangled" >&2
  if [[ "$probe_lines" -eq 0 ]]; then
    echo "::error::xtrace probe captured no usable records via ${probe_bash} — coverage mechanism broken" >&2
    exit 2
  fi
  if [[ "$probe_bad" -gt 0 ]]; then
    echo "::error::${probe_bash} (bash ${probe_version}) truncates the PS4 expansion, mangling trace records." >&2
    echo "::error::REPO_ROOT is ${#REPO_ROOT} characters; records emitted through that bash lose their terminator and are dropped." >&2
    echo "::error::Use a shorter checkout path, or put a bash >= 4.1 ahead of ${probe_bash} on PATH." >&2
    exit 2
  fi
}

# Sanity-probe: run one trivial script through the pipeline so a
# subsequent failure of the real sweep can be diagnosed quickly.
_cov_probe() {
  local probe_target probe_bash
  local -a probe_bashes
  probe_target="$COVERAGE_DIR/_probe_target.sh"
  cat >"$probe_target" <<'PROBE'
#!/usr/bin/env bash
set -uo pipefail
echo "probe-line-a"
x=1; y=2
echo "probe-sum=$((x + y))"
PROBE
  chmod +x "$probe_target"

  # Probe every bash a test could plausibly reach: the one on PATH, and
  # /bin/bash when it is a different binary (macOS ships 3.2 there). A
  # record is only usable if it survives *intact*, terminator included —
  # hence the `:@` in the pattern.
  probe_bashes=("bash")
  if [[ -x /bin/bash ]] && [[ "$(command -v bash)" != "/bin/bash" ]]; then
    probe_bashes+=("/bin/bash")
  fi
  for probe_bash in "${probe_bashes[@]}"; do
    _cov_probe_one "$probe_bash"
  done
}

# -----------------------------------------------------------------------------
# Collect test files (mirror tests/framework/test_runner.sh discovery).
# -----------------------------------------------------------------------------
# Portable read — `mapfile` is bash 4 only and this runner documents
# macOS support, where /bin/bash is 3.2.
_cov_collect_tests() {
  local _line _rel
  test_files=()
  skipped_tests=()
  while IFS= read -r _line; do
    [[ -n "$_line" ]] || continue
    _rel="${_line#"$TESTS_DIR"/}"
    case ":$COV_SKIP_TESTS:" in
      *":$_rel:"*)
        skipped_tests+=("$_rel")
        continue
        ;;
    esac
    test_files+=("$_line")
  done < <(find "$TESTS_DIR/unit" "$TESTS_DIR/regression" -name 'test_*.sh' -type f | sort)

  if [[ "${#test_files[@]}" -eq 0 ]]; then
    echo "::error::no unit or regression test files discovered under $TESTS_DIR" >&2
    exit 1
  fi

  if [[ "${#skipped_tests[@]}" -gt 0 ]]; then
    echo "skipped-by-policy: ${#skipped_tests[@]} test(s): ${skipped_tests[*]}" >&2
  fi

  echo "Tracing ${#test_files[@]} test files (parallel × $JOBS, timeout ${COV_TEST_TIMEOUT}s/test)..." >&2
}

# -----------------------------------------------------------------------------
# Worker function — runs one test under xtrace, captures stderr.
# -----------------------------------------------------------------------------
# shellcheck disable=SC2317,SC2329  # called indirectly via xargs subshell
run_one() {
  local f="$1"
  local relative trace slug status started ended
  relative="${f#"$COV_TESTS_DIR"/}"
  slug="${relative//\//__}"
  trace="$COV_TRACE_DIR/${slug}.trace"
  : >"$trace"
  started=$(date +%s)
  # `</dev/null` and `>/dev/null` on purpose: a test that backgrounds a
  # grandchild leaves it holding whatever descriptors it inherited, and
  # if those are the runner's own stdin/stdout pipes (they are, whenever
  # a caller wraps this script in a command substitution) the sweep
  # appears to hang long after every test has finished. Handing each test
  # /dev/null for both ends makes an orphan unable to hold the pipeline
  # open. The timeout wrapper — GNU `timeout`, `gtimeout`, or the perl
  # fallback — signals the whole process group, so orphans are killed
  # rather than merely detached; `--kill-after=5` finishes off anything
  # that ignores SIGTERM.
  if [[ -n "${COV_TIMEOUT_CMD:-}" ]]; then
    PS4="$COV_PS4" \
      BASH_ENV="$COV_BASH_ENV" \
      COV_TRACE_FILE="$trace" \
      "$COV_TIMEOUT_CMD" --kill-after=5 "$COV_TEST_TIMEOUT" \
      bash "$f" 2>"$trace" >/dev/null </dev/null
    status=$?
  else
    # No timeout available (stock macOS): run without the hang-guard.
    PS4="$COV_PS4" \
      BASH_ENV="$COV_BASH_ENV" \
      COV_TRACE_FILE="$trace" \
      bash "$f" 2>"$trace" >/dev/null </dev/null
    status=$?
  fi
  ended=$(date +%s)
  # One record per test: exit status, wall-clock seconds, relative path.
  # The post-sweep audit turns timeout kills into a hard error and
  # reports the slowest tests so the budget stays defensible.
  printf '%s\t%s\t%s\n' "$status" "$((ended - started))" "$relative" \
    >"$COV_STATUS_DIR/${slug}.status"
}

_cov_sweep() {
  local start_ts elapsed
  export COV_TRACE_DIR="$trace_dir"
  export COV_STATUS_DIR="$status_dir"
  export COV_PS4
  export COV_BASH_ENV="$bash_env"
  export COV_TESTS_DIR="$TESTS_DIR"
  export COV_TEST_TIMEOUT
  export COV_TIMEOUT_CMD
  # Function-file probes retain stderr temporarily so normal unit runs stay
  # quiet. Replay it here because it contains the source function xtrace that
  # the coverage aggregator must see.
  export DOTFILES_COV_ECHO_STDERR=1
  export -f _cov_perl_timeout
  export -f run_one

  start_ts=$(date +%s)
  printf '%s\n' "${test_files[@]}" |
    xargs -I{} -n1 -P"$JOBS" bash -c 'run_one "$@"' _ {} ||
    true
  elapsed=$(($(date +%s) - start_ts))
  echo "trace phase done in ${elapsed}s" >&2
}

# -----------------------------------------------------------------------------
# Completeness audit — did every discovered test actually run?
#
# `xargs … || true` swallows a worker that died before it could record a
# status: `xargs: bash: terminated with signal 15` scrolls past, the sweep
# stops early, and the aggregator happily prints a percentage computed
# from a fraction of the suite. That is the same silent-wrong-number
# failure as the timeout kill, arriving by a different door — a sweep
# interrupted at 230 of 670 tests reported 47.28% and exited 0 — so the
# count of status records is checked against the count of tests dispatched.
# -----------------------------------------------------------------------------
_cov_audit_completeness() {
  local f rel missing
  ran_count=$(find "$status_dir" -name '*.status' -type f | wc -l | tr -d ' ')
  echo "tests-completed: ${ran_count}/${#test_files[@]}" >&2
  cov_incomplete=0
  if [[ "$ran_count" -ne "${#test_files[@]}" ]]; then
    cov_incomplete=1
    echo "::error::only ${ran_count} of ${#test_files[@]} tests recorded a result — the sweep did not finish, so any percentage below is computed from a fraction of the suite" >&2
    missing=0
    for f in "${test_files[@]}"; do
      rel="${f#"$TESTS_DIR"/}"
      if [[ ! -e "$status_dir/${rel//\//__}.status" ]]; then
        missing=$((missing + 1))
        [[ "$missing" -le 10 ]] && echo "::error::no result recorded for: $rel" >&2
      fi
    done
    [[ "$missing" -gt 10 ]] && echo "::error::… and $((missing - 10)) more" >&2
  fi
}

# -----------------------------------------------------------------------------
# Timeout audit — a killed test contributes no trace records, so it silently
# removes its share of the numerator while leaving the denominator intact.
# That made the reported percentage a function of machine load: two runs over
# an identical tree could disagree by whole points, and individual files could
# appear to lose coverage between runs that never touched them.
#
# Kills are therefore a HARD ERROR. lcov.info is still written (the artifact
# and the per-file detail stay useful for debugging) but the runner exits
# non-zero and names every killed file, so the number is never quietly wrong.
#
# `timeout` reports 124 when it had to signal the child, and 137 when the
# child had to be SIGKILLed after --kill-after; the perl fallback reports
# 124. Requiring the observed duration to have reached the budget as well
# keeps a test that genuinely exits 124 from being misreported as a kill.
# -----------------------------------------------------------------------------
_cov_audit_timeouts() {
  local st dur rel slowest_report="" k
  killed_tests=()
  slowest_report=""
  if [[ -d "$status_dir" ]]; then
    while IFS=$'\t' read -r st dur rel; do
      [[ -n "${rel:-}" ]] || continue
      if [[ "$st" == "124" || "$st" == "137" ]] && [[ "$dur" -ge "$COV_TEST_TIMEOUT" ]]; then
        killed_tests+=("$rel (${dur}s, exit $st)")
      fi
    done < <(cat "$status_dir"/*.status 2>/dev/null)
    slowest_report=$(sort -t$'\t' -k2,2nr "$status_dir"/*.status 2>/dev/null |
      head -5 | awk -F'\t' '{printf "  %5ss  %s\n", $2, $3}')
  fi

  if [[ -n "$slowest_report" ]]; then
    echo "slowest tests (budget ${COV_TEST_TIMEOUT}s):" >&2
    printf '%s\n' "$slowest_report" >&2
  fi

  cov_timeout_failure=0
  if [[ "${#killed_tests[@]}" -gt 0 ]]; then
    cov_timeout_failure=1
    echo "::error::${#killed_tests[@]} test(s) exceeded COV_TEST_TIMEOUT=${COV_TEST_TIMEOUT}s and were killed; coverage is understated and non-deterministic" >&2
    for k in "${killed_tests[@]}"; do
      echo "::error::killed by coverage timeout: $k" >&2
    done
    echo "killed-by-timeout: ${#killed_tests[@]} test(s): ${killed_tests[*]}" >&2
  else
    echo "killed-by-timeout: 0 test(s)" >&2
  fi
}

# -----------------------------------------------------------------------------
# Silent-trace audit — the other way a test contributes nothing without
# saying so. A test that redirects its whole stderr away (`exec 2>…`, or a
# wrapper that captures the suite itself) hands us an empty trace while
# exiting cleanly: the tests ran, the coverage vanished. BASH_XTRACEFD
# above stops that happening for *children* a test captures, but it cannot
# help a shell too old for BASH_XTRACEFD or a test that redirects the
# runner's own descriptor, so the result is checked rather than assumed.
#
# Warning, not error: a trace can legitimately be thin, and this is a
# signal to go and look, not a verdict.
# -----------------------------------------------------------------------------
_cov_audit_silent() {
  local status_file slug trace_file rel s
  local -a silent_tests=()
  silent_tests=()
  for status_file in "$status_dir"/*.status; do
    [[ -e "$status_file" ]] || continue
    slug="$(basename "$status_file" .status)"
    trace_file="$trace_dir/${slug}.trace"
    rel="$(cut -f3 "$status_file")"
    if [[ ! -s "$trace_file" ]] ||
      ! grep -qE '^\++@COV@:[0-9]+:' "$trace_file" 2>/dev/null; then
      silent_tests+=("${rel:-$slug}")
    fi
  done
  if [[ "${#silent_tests[@]}" -gt 0 ]]; then
    echo "::warning::${#silent_tests[@]} test(s) produced no xtrace records at all — their stderr is being redirected away and their coverage is lost" >&2
    for s in "${silent_tests[@]}"; do
      echo "::warning::no coverage captured from: $s" >&2
    done
    echo "silent-traces: ${#silent_tests[@]} test(s): ${silent_tests[*]}" >&2
  else
    echo "silent-traces: 0 test(s)" >&2
  fi
}

# -----------------------------------------------------------------------------
# Aggregate trace files → lcov.info (tools/ci/coverage_aggregate.py).
# -----------------------------------------------------------------------------
_cov_aggregate() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/coverage_aggregate.py" \
    "$COVERAGE_OUT" "$trace_dir" "$REPO_ROOT" "$COV_INCLUDE_DIRS"
  aggregate_ec=$?

  if [[ ! -s "$COVERAGE_OUT" ]]; then
    echo "::error::failed to produce lcov.info — aggregator wrote empty file." >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Threshold check.
# -----------------------------------------------------------------------------
_cov_threshold() {
  local summary covered total pct below
  summary=$(
    python3 - "$COVERAGE_OUT" <<'PY'
import sys
total = covered = 0
with open(sys.argv[1]) as f:
    for line in f:
        if line.startswith("DA:"):
            _, rest = line.split(":", 1)
            _, hits = rest.strip().split(",")
            total += 1
            if int(hits) > 0:
                covered += 1
pct = (covered * 100.0 / total) if total else 0.0
print(f"{covered} {total} {pct:.2f}")
PY
  )
  read -r covered total pct <<<"$summary"
  echo "Coverage: ${covered}/${total} lines = ${pct}% (output: $COVERAGE_OUT)"

  below=$(awk -v p="$pct" -v t="$MIN_COVERAGE_PCT" 'BEGIN{print (p+0 < t+0) ? "1" : "0"}')
  if [[ "$below" == "1" ]]; then
    echo "::error::coverage ${pct}% is below the floor ${MIN_COVERAGE_PCT}%" >&2
    exit 1
  fi
}

# Reported last so the coverage number is still visible above it: a killed
# test or a mangled record invalidates the measurement even when the
# surviving tests clear the floor.
_cov_verdict() {
  if [[ "$cov_incomplete" -eq 1 ]]; then
    echo "::error::coverage measurement is invalid — the sweep ran ${ran_count} of ${#test_files[@]} tests" >&2
    exit 5
  fi

  if [[ "$cov_timeout_failure" -eq 1 ]]; then
    echo "::error::coverage measurement is invalid — ${#killed_tests[@]} test(s) killed by COV_TEST_TIMEOUT" >&2
    exit 3
  fi

  if [[ "$aggregate_ec" -ne 0 ]]; then
    echo "::error::coverage measurement is invalid — trace records for measured files were truncated (aggregator exit ${aggregate_ec})" >&2
    exit "$aggregate_ec"
  fi
  exit 0
}

_cov_main() {
  _cov_setup_dirs
  _cov_write_bash_env
  _cov_probe
  _cov_collect_tests
  _cov_sweep
  _cov_audit_completeness
  _cov_audit_timeouts
  _cov_audit_silent
  _cov_aggregate
  _cov_threshold
  _cov_verdict
}

_cov_main "$@"
