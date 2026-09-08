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
COV_TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  COV_TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  COV_TIMEOUT_CMD="gtimeout"
elif command -v perl >/dev/null 2>&1; then
  COV_TIMEOUT_CMD="_cov_perl_timeout"
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

mkdir -p "$COVERAGE_DIR"
trace_dir="$COVERAGE_DIR/traces"
rm -rf "$trace_dir"
mkdir -p "$trace_dir"
status_dir="$COVERAGE_DIR/status"
rm -rf "$status_dir"
mkdir -p "$status_dir"

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
export COV_ROOT="$REPO_ROOT"
COV_PS4='+@COV@:${LINENO}:${BASH_SOURCE[0]:+${BASH_SOURCE[0]#${COV_ROOT:-__cov_unset__}/}}:@ '

# BASH_ENV setup file: enables xtrace in every non-interactive bash that
# inherits it. Child processes spawned via `bash $SCRIPT` get their own
# tracing turned on automatically.
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

# Sanity-probe: run one trivial script through the pipeline so a
# subsequent failure of the real sweep can be diagnosed quickly.
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
done

# -----------------------------------------------------------------------------
# Collect test files (mirror tests/framework/test_runner.sh discovery).
# -----------------------------------------------------------------------------
# Portable read — `mapfile` is bash 4 only and this runner documents
# macOS support, where /bin/bash is 3.2.
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

# -----------------------------------------------------------------------------
# Aggregate trace files → lcov.info.
# -----------------------------------------------------------------------------
python3 - "$COVERAGE_OUT" "$trace_dir" "$REPO_ROOT" "$COV_INCLUDE_DIRS" <<'PY'
"""Aggregate bash xtrace output into lcov.info."""
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

out_path, trace_dir, repo_root, include_dirs_spec = sys.argv[1:5]
include_dirs = [Path(p).resolve() for p in include_dirs_spec.split(":") if p]
trace_dir = Path(trace_dir)
repo_root = Path(repo_root).resolve()

# -----------------------------------------------------------------------------
# Skip-list — paths (relative to repo_root) that the xtrace mechanism
# cannot measure meaningfully in our sandbox. Listed once at the
# aggregator level so individual scripts don't need to be peppered with
# LCOV_EXCL_START/STOP markers. Categories:
#   1. Interactive / animation scripts (matrix, pipes, banner, cmatrix,
#      stopwatch, rainbow, ql) — require a TTY + user input; the
#      function body never returns to xtrace within a test budget.
#   2. Self-reference — run-coverage.sh is the runner itself; the
#      runner traces other scripts but not itself.
#   3. CI-only entry points that mutate real environments (pre-push,
#      release, install, bump, lint, check-deps-dev, validate-ci-config,
#      reliability-audit, coverage-baseline, lint-reusable-pins).
#   4. Top-level system-mutation scripts that need real OS state
#      (rebuild-themes scans wallpapers; apply-gnome-theme drives
#      gsettings; wallpaper-sync pulls from a remote; build-manual
#      shells out to pandoc; chaos.sh and record.sh produce side
#      effects we can't fake under bash xtrace).
# Files here are entirely removed from the lcov denominator (no SF:
# entry emitted). The covered code in the *rest* of the repo is the
# meaningful denominator.
# -----------------------------------------------------------------------------
SKIP_PATHS = {
    # Interactive / animation — require a TTY + user input.
    "defaults/.chezmoitemplates/functions/interactive/matrix.sh",
    "defaults/.chezmoitemplates/functions/interactive/cmatrix.sh",
    "defaults/.chezmoitemplates/functions/interactive/stopwatch.sh",
    "defaults/.chezmoitemplates/functions/interactive/banner.sh",
    "defaults/.chezmoitemplates/functions/interactive/rainbow.sh",
    "defaults/.chezmoitemplates/functions/interactive/pipes.sh",
    "defaults/.chezmoitemplates/functions/misc/pipes.sh",
    "defaults/.chezmoitemplates/functions/misc/view-source.sh",
    "defaults/.chezmoitemplates/functions/misc/caffeine.sh",   # daemon controller, real /tmp/lock
    "defaults/.chezmoitemplates/functions/nav/ql.sh",
    "scripts/tools/pipes.sh",
    "scripts/tools/cmatrix.sh",
    "scripts/demo/record.sh",
    "defaults/dot_local/bin/executable_tmux-sessionizer",
    "defaults/dot_local/bin/executable_myip",
    "defaults/dot_local/bin/executable_tour",                  # requires TTY + gum
    # Self-reference + CI gates
    "tools/ci/run-coverage.sh",
    "tools/ci/check-deps-dev.sh",
    "tools/ci/lint-reusable-pins.sh",
    "tools/ci/validate-chezmoidata.sh",
    "tools/ci/validate-ci-config.sh",
    "tools/ci/check-dangerous-chmod.sh",
    "scripts/git-hooks/pre-push",
    "scripts/qa/reliability-audit.sh",
    "scripts/qa/coverage-baseline.sh",
    "scripts/dot/commands/lint.sh",
    # System mutation — drives real OS state we can't fake under xtrace.
    "scripts/theme/rebuild-themes.sh",
    "scripts/theme/apply-gnome-theme.sh",
    "scripts/theme/wallpaper-sync.sh",
    "scripts/theme/install-catppuccin-themes.sh",
    "scripts/ops/chaos.sh",
    "scripts/ops/release.sh",
    "scripts/ops/heal-tools.sh",
    "scripts/ops/chezmoi-apply.sh",
    "tools/docs/build-manual.sh",
    "scripts/security/manage-secrets.sh",
    "scripts/security/enforce-policies.sh",
    "scripts/security/ssh-cert.sh",
    "scripts/security/firewall.sh",
    "scripts/lib/secrets_provider.sh",                # keychain/gpg/age bindings
    "scripts/ops/setup.sh",                           # post-install bootstrap
    "scripts/theme/wallpaper-rotate.sh",              # cron-driven wallpaper change
    "scripts/git-hooks/pre-commit-audit.sh",          # full hook flow needs real index
    "bin/dot-theme-sync",        # signals live apps
    "bin/dot-bootstrap",
    "defaults/dot_local/bin/executable_update",
    "defaults/dot_local/bin/executable_ai_core",
    "defaults/dot_local/bin/executable_ai-update",
}

def is_skipped(abs_path: Path) -> bool:
    try:
        rel = abs_path.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        return False
    return rel in SKIP_PATHS

# Bash adds one xtrace prefix for each nested execution context. Count both
# top-level `+@COV@` records and `++@COV@`/`+++@COV@` records emitted from
# functions inside command substitutions and subshells.
# `[^:]*` (not `[^:]+`): a `bash -c` top level has no BASH_SOURCE[0], so
# the field is legitimately empty. Those records name no file and are
# skipped below — but they must still MATCH here, or the truncation audit
# would mistake every one of them for a mangled record.
hit_re = re.compile(r"^\++@COV@:(\d+):([^:]*):@")

# A record that starts like ours but has lost its `:@ ` terminator was
# truncated in flight — bash 3.2 cuts the expanded PS4 at 100 characters.
# Such a record is silently unusable, which is exactly the failure mode
# this runner must never have, so they are counted and reported.
record_head_re = re.compile(r"^\++@COV@:(\d+):(.*)$")
truncated_records = Counter()
truncated_by_trace = Counter()

# raw_hits[abs_path][line] = total trace records seen for that physical line
raw_hits = defaultdict(lambda: defaultdict(int))
source_cache = {}

def in_includes(path: Path) -> bool:
    try:
        rp = path.resolve()
    except (OSError, RuntimeError):
        return False
    for inc in include_dirs:
        try:
            rp.relative_to(inc)
            return True
        except ValueError:
            continue
    return False

def normalized_source(src: str):
    """Resolve and classify each distinct xtrace source path once."""
    if src in source_cache:
        return source_cache[src]
    src_path = Path(src)
    if not src_path.is_absolute():
        src_path = repo_root / src_path
    try:
        src_path = src_path.resolve()
    except (OSError, RuntimeError):
        pass
    result = str(src_path) if in_includes(src_path) and not is_skipped(src_path) else None
    source_cache[src] = result
    return result

# Parse every trace file. Each trace can be MBs; iterate line by line.
for trace_path in sorted(trace_dir.glob("*.trace")):
    try:
        with open(trace_path, "r", errors="replace") as f:
            for line in f:
                m = hit_re.match(line)
                if not m:
                    head = record_head_re.match(line)
                    if head:
                        truncated_records[head.group(2)[:80]] += 1
                        truncated_by_trace[trace_path.name] += 1
                    continue
                lineno = int(m.group(1))
                src = m.group(2).strip()
                if not src or src == "main":
                    continue
                # Resolve once per distinct source string. Trace files can
                # contain millions of records but only hundreds of sources.
                # Caching avoids repeated filesystem resolution while still
                # collapsing `..` paths into one canonical lcov SF entry.
                source_path = normalized_source(src)
                if source_path is None:
                    continue
                raw_hits[source_path][lineno] += 1
    except OSError as e:
        print(f"warn: read error {trace_path}: {e}", file=sys.stderr)

# -----------------------------------------------------------------------------
# Source analysis — which physical lines can bash xtrace ever report, and
# which physical line does it report a multi-line statement on?
#
# `set -x` does NOT emit a record for every line that runs. Several
# constructs execute perfectly well and never produce a `+@COV@:` record at
# their own line number, so counting them as "executable" put permanently
# unhittable lines in the denominator and capped per-file coverage well
# below 100%. Every exclusion below was established by running a fixture
# under this runner's own PS4 + `set -x` and observing that no record
# appears for the line; the fixtures live in
# tests/unit/ci/test_run_coverage_aggregator.sh and are asserted on every
# run so this classifier cannot silently drift.
#
# Observed (bash 5.3, and the same on 5.2):
#
#   1. Function-definition headers. `greet() {`, `greet()` + `{` on the
#      next line, and `function greet {` all emit nothing; only the body
#      is traced. A one-line definition (`f() { echo hi; }`) IS traced,
#      because the body is on that line — so it stays in the denominator.
#
#   2. `case` pattern labels. `a | x)`, `"hello world")`, `'')` and `*)`
#      emit nothing even when the arm matches; the arm's body is what
#      gets traced. The old `case_pattern` regex only recognised bare
#      `foo)`, so every label with alternation, quoting or a space was
#      still counted. A label with its body on the same line
#      (`x) echo x ;;`) IS traced and stays.
#
#   3. Interior lines of a multi-line *word*: an unterminated `$( )`,
#      `<( )`, `>( )`, backtick, `name=( )` array assignment, `$(( ))`,
#      or an unterminated quoted string. Nothing inside is ever reported
#      at its own line; bash attributes the whole statement to ONE
#      physical line of the construct — sometimes the first, sometimes
#      the last:
#
#        a=$(          -> record lands on the closing `)` line
#          echo A
#        )
#        echo "$(      -> record lands on the `echo` line
#          echo B
#        )"
#
#      Guessing which end would risk dropping a genuinely covered line,
#      so instead the statement is *folded*: the first physical line is
#      the single denominator entry, and a record on any later physical
#      line of the same statement counts as a hit on it (`alias` below).
#      That is exact — one logical statement, one denominator slot, hit
#      iff bash traced it anywhere — and needs no guess.
#
#   4. Backslash-continuation lines that carry only more words of the
#      same command (`printf '%s' \` / `"one" \` / `"two"`): only the
#      first line is traced. But a continuation that STARTS a new
#      command is traced at its own line (`true && \` / `  echo x`, or
#      `cmd \` / `  || echo fallback`), so those are kept. The
#      discriminator is an operator at the head of the continuation or
#      at the tail of the line before it.
#
#   5. Compound terminators carrying only a redirection: `done <"$f"`,
#      `fi >/dev/null`, `} >/dev/null` emit nothing — the redirection is
#      set up by the compound command, which was already traced at its
#      head. `done | cat` IS traced (the pipeline's next element runs
#      there) and `done < <(cmd)` IS traced (the process substitution's
#      body runs there), so both stay.
#
# Deliberately NOT excluded — see the report in #883 for the evidence:
#   * `(` / `)` of a bare subshell group and `{` / `}` of a brace group:
#     already dropped by the structural rule, and the statements INSIDE
#     such a group are traced at their own lines, so they stay.
#   * Lines that are merely untested (an `if` branch never taken, a
#     function never called). Those are the thing coverage is for.
#   * `x) ;;` — a case label with an empty body on the same line emits
#     nothing, but the shape is indistinguishable from `x) cmd ;;`
#     without a real parser. Left in the denominator; it understates.
# -----------------------------------------------------------------------------
heredoc_re = re.compile(
    r"""<<(-?)\s*(?:"([^"]*)"|'([^']*)'|\\?([A-Za-z_][A-Za-z0-9_.\-]*))"""
)
excl_line_re = re.compile(r"#\s*LCOV_EXCL_LINE")
excl_start_re = re.compile(r"#\s*LCOV_EXCL_START")
excl_stop_re = re.compile(r"#\s*LCOV_EXCL_STOP")
# Scripts that explicitly turn off xtrace can't be measured by this
# mechanism — the bash runtime simply stops emitting trace records.
# Treat everything after `set +x` / `set +o xtrace` as excluded so it
# doesn't sink the denominator.
xtrace_off_re = re.compile(r"^\s*set\s+(\+x|\+o\s+xtrace)\b")
structural_re = re.compile(
    r"^\s*("
    r"fi|done|else|elif|esac|then|do|in|"
    r"\}|\{|\(|"
    r"\)\s*;?;?\s*$|"  # bare `)` (subshell / case-pattern close)
    r";;&?\s*$|"       # `;;` / `;;&` case-clause terminators
    r";&\s*$"          # `;&` fallthrough terminator
    r")\s*(#.*)?$"
)
func_hdr_re = re.compile(
    r"^\s*(function\s+)?[A-Za-z_][A-Za-z0-9_:.+\-]*\s*\(\s*\)\s*(\{\s*)?(#.*)?$"
)
func_hdr_kw_re = re.compile(
    r"^\s*function\s+[A-Za-z_][A-Za-z0-9_:.+\-]*\s*(\{\s*)?(#.*)?$"
)
case_open_re = re.compile(r"^\s*case\b")
esac_re = re.compile(r"^\s*esac\b")
terminator_redir_re = re.compile(
    r"^\s*(done|fi|esac|\}|\))\s+(?P<rest>[0-9]*[<>].*)$"
)
cont_op_head_re = re.compile(r"^\s*(\|\||&&|\||;;?|&)")
# A backslash-continued command whose continuation begins with `&&` or
# `||` is attributed to the OPERATOR line, not its own, on bash 5.2 —
# and to its own line on 5.3. See the note in classify().
cont_andor_re = re.compile(r"^\s*(&&|\|\|)")
cont_op_tail_re = re.compile(
    r"(\|\||&&|\||;|&|\(|\{|!|\bthen\b|\bdo\b|\belse\b)\s*$"
)
WORDISH = ("word", "arith", "btick")

def scan_line(line, st):
    """Advance the shell lexer state across one physical line.

    `st` carries `quote` (None / `'` / `"`) and `stack` (open word-level
    or command-level groupings) across lines, which is what tells us
    whether the next physical line continues this statement.
    """
    quote = st["quote"]
    stack = st["stack"]
    heredocs = []
    has_subst = False
    unmatched_close = 0
    ends_with_backslash = False

    i = 0
    n = len(line)
    while i < n:
        c = line[i]

        if quote == "'":
            if c == "'":
                quote = None
            i += 1
            continue

        if c == "\\":
            # A trailing backslash continues the line everywhere except
            # inside single quotes (handled above).
            if i + 1 >= n:
                ends_with_backslash = True
                i += 1
            else:
                i += 2
            continue

        if quote == '"':
            # `$(`, `$((` and backticks re-open command context inside a
            # double-quoted word; remember the quote so it is restored
            # when the substitution closes.
            if c == '"':
                quote = None
                i += 1
                continue
            if c == "$" and i + 1 < n and line[i + 1] == "(":
                if i + 2 < n and line[i + 2] == "(":
                    stack.append(("arith", quote))
                    i += 3
                else:
                    stack.append(("word", quote))
                    has_subst = True
                    i += 2
                quote = None
                continue
            if c == "`":
                stack.append(("btick", quote))
                has_subst = True
                quote = None
                i += 1
                continue
            i += 1
            continue

        # Unquoted.
        if c == "#" and (i == 0 or line[i - 1] in " \t;&|("):
            break  # comment runs to end of line

        if c == "'":
            quote = "'"
            i += 1
            continue
        if c == '"':
            quote = '"'
            i += 1
            continue
        if c == "`":
            if stack and stack[-1][0] == "btick":
                quote = stack.pop()[1]
            else:
                stack.append(("btick", None))
                has_subst = True
            i += 1
            continue

        if c == "$" and i + 1 < n and line[i + 1] == "(":
            if i + 2 < n and line[i + 2] == "(":
                stack.append(("arith", None))
                i += 3
            else:
                stack.append(("word", None))
                has_subst = True
                i += 2
            continue

        if c in "<>" and i + 1 < n and line[i + 1] == "(":
            stack.append(("word", None))  # process substitution
            has_subst = True
            i += 2
            continue

        if c == "=" and i + 1 < n and line[i + 1] == "(":
            stack.append(("word", None))  # `name=(` / `name+=(` array
            i += 2
            continue

        if c == "(":
            if i + 1 < n and line[i + 1] == "(":
                stack.append(("arith", None))
                i += 2
            else:
                stack.append(("cmd", None))  # subshell group
                i += 1
            continue

        if c == ")":
            if stack:
                kind, saved = stack.pop()
                if kind == "arith" and i + 1 < n and line[i + 1] == ")":
                    i += 1
                quote = saved
            else:
                unmatched_close += 1
            i += 1
            continue

        # `<<<` is a here-string, not a here-document: consume it whole so
        # its word is never mistaken for a here-doc terminator.
        if c == "<" and line[i + 1:i + 3] == "<<":
            i += 3
            continue

        # `<<` opens a here-document, but `1 << 2` inside `$(( ))` is a
        # left shift — the arith guard keeps the two apart.
        if (
            c == "<"
            and i + 1 < n
            and line[i + 1] == "<"
            and not any(k == "arith" for k, _ in stack)
        ):
            m = heredoc_re.match(line, i)
            if m:
                heredocs.append((m.group(2) or m.group(3) or m.group(4),
                                 m.group(1) == "-"))
                i = m.end()
                continue
            i += 2
            continue

        i += 1

    st["quote"] = quote
    return {
        "heredocs": heredocs,
        "has_subst": has_subst,
        "unmatched_close": unmatched_close,
        "ends_with_backslash": ends_with_backslash and quote != "'",
    }

def strip_comment(line):
    """Drop a trailing unquoted `#` comment."""
    quote = None
    for i, c in enumerate(line):
        if quote:
            if c == quote:
                quote = None
            continue
        if c in "\"'":
            quote = c
        elif c == "#" and (i == 0 or line[i - 1] in " \t;&|("):
            return line[:i]
    return line

def is_case_label(line):
    """True for a `case` pattern label with no command on the line.

    Quote-aware: the line must close exactly one paren it never opened
    and end there, which covers `*)`, `a | x)`, `"hello world")`, `'')`
    and the `(a|b)` form, while rejecting `x) echo x ;;` (traced) and
    ordinary code containing balanced parens.
    """
    body = strip_comment(line).rstrip()
    if not body.endswith(")"):
        return False
    probe = body.strip()
    if probe.startswith("("):
        probe = probe[1:]
    st = {"quote": None, "stack": []}
    info = scan_line(probe, st)
    if st["quote"] or st["stack"]:
        return False
    return info["unmatched_close"] == 1

def classify(line, is_start, cont_reason, prev_code, logical_has_subst,
             case_depth, excluding, xtrace_disabled):
    """Return "exec" (denominator entry), "alias" (fold onto the
    statement's first line) or "skip" (not measurable at all)."""
    if excluding or excl_start_re.search(line) or excl_stop_re.search(line):
        return "skip"
    if excl_line_re.search(line):
        return "skip"
    if xtrace_disabled:
        return "skip"

    if not is_start:
        if cont_reason == "quote":
            return "alias"
        # Backslash continuation: traced only when it begins a new
        # command, which an operator at either join point signals.
        if cont_op_head_re.match(line):
            return "exec"
        tail = strip_comment(prev_code).rstrip()
        if tail.endswith("\\"):
            tail = tail[:-1].rstrip()
        if cont_op_tail_re.search(tail):
            return "exec"
        return "alias"

    if not line or not line.strip():
        return "skip"
    if line.lstrip().startswith("#"):
        return "skip"
    if xtrace_off_re.match(line):
        return "skip"
    if structural_re.match(line):
        return "skip"
    if func_hdr_re.match(line) or func_hdr_kw_re.match(line):
        return "skip"
    if case_depth > 0 and is_case_label(line):
        return "skip"
    m = terminator_redir_re.match(strip_comment(line))
    if m and not logical_has_subst and not re.search(r"(\|\||&&|\||;)",
                                                     m.group("rest")):
        return "skip"
    return "exec"

analysis_cache = {}

def analyze(path):
    """Return (executable_lines, alias) for one shell file.

    `executable_lines` is the set of physical lines that belong in the
    lcov denominator. `alias` maps every other physical line of a
    multi-line statement (and here-doc bodies) onto that statement's
    denominator line, so a trace record landing on a later physical line
    still counts as a hit for the statement.
    """
    key = str(path)
    if key in analysis_cache:
        return analysis_cache[key]
    try:
        with open(key, "r", errors="replace") as f:
            text = f.read().splitlines()
    except OSError:
        analysis_cache[key] = (set(), {})
        return analysis_cache[key]

    exec_lines = set()
    alias = {}
    st = {"quote": None, "stack": []}
    heredoc_queue = []
    in_heredoc = None
    stmt_start = 1
    cont_reason = None
    prev_code = ""
    logical_has_subst = False
    case_depth = 0
    excluding = False
    xtrace_disabled = False

    for i, line in enumerate(text):
        lineno = i + 1

        if in_heredoc is not None:
            # Here-doc bodies are data, not commands. Fold them onto the
            # statement that opened them so a stray record can't invent
            # a denominator entry.
            alias[lineno] = stmt_start
            term, strip_tabs = in_heredoc
            probe = line.lstrip("\t") if strip_tabs else line
            if probe.strip() == term:
                in_heredoc = heredoc_queue.pop(0) if heredoc_queue else None
            continue

        is_start = cont_reason is None
        if is_start:
            stmt_start = lineno
            logical_has_subst = False

        info = scan_line(line, st)
        logical_has_subst = logical_has_subst or info["has_subst"]

        verdict = classify(line, is_start, cont_reason, prev_code,
                           logical_has_subst, case_depth, excluding,
                           xtrace_disabled)

        # Which bash you run decides where the head of a backslash-joined
        # `&&`/`||` list is reported, so neither answer can be trusted:
        #
        #     true \\
        #       && echo hi
        #
        # bash 5.3 traces `true` at its own line; bash 5.2 — every current
        # Linux runner — traces it at the `&&` line, which then carries two
        # records and leaves the head permanently unhittable. Dropping the
        # head makes the denominator identical on both, at the cost of one
        # covered line on 5.3. The operator line keeps its own entry, so a
        # short-circuited right-hand side is still reported as missed.
        #
        # Narrow on purpose: only the STATEMENT-START head, and only for
        # `&&`/`||`. An intermediate `&& cmd \\` in a longer chain is traced
        # on both (observed), as are `|`, `;` and a trailing-operator join
        # (`true && \\`), so all of those keep their line.
        if (
            verdict == "exec"
            and is_start
            and info["ends_with_backslash"]
            and not st["quote"]
            and not any(k in WORDISH for k, _ in st["stack"])
            and lineno < len(text)
            and cont_andor_re.match(text[lineno])
        ):
            verdict = "skip"

        # `done < <(` whose process substitution spans lines is another
        # version-dependent attribution. bash 5.x runs the substitution's
        # body at the closing paren, which folds onto this line; bash 3.2
        # attributes it to the `while`/`for` header instead, leaving the
        # whole `done < <( … )` region with no record at all. Excluded, so
        # the denominator agrees across versions.
        #
        # The single-line `done < <(cmd)` IS traced on both (observed), so
        # the classify() rule keeps it — only the spanning form is dropped.
        if (
            verdict == "exec"
            and is_start
            and (st["quote"] or any(k in WORDISH for k, _ in st["stack"]))
            and terminator_redir_re.match(strip_comment(line))
        ):
            verdict = "skip"

        if excl_start_re.search(line):
            excluding = True
        elif excl_stop_re.search(line):
            excluding = False
        if is_start and xtrace_off_re.match(line):
            xtrace_disabled = True

        if is_start and not excluding:
            if case_open_re.match(line):
                case_depth += 1
            elif esac_re.match(line):
                case_depth = max(0, case_depth - 1)

        if verdict == "exec":
            exec_lines.add(lineno)
            stmt_start = lineno
        elif verdict == "alias":
            alias[lineno] = stmt_start

        if info["heredocs"]:
            heredoc_queue.extend(info["heredocs"])

        if st["quote"] or any(k in WORDISH for k, _ in st["stack"]):
            cont_reason = "quote"
        elif info["ends_with_backslash"]:
            cont_reason = "backslash"
        else:
            cont_reason = None

        if heredoc_queue:
            in_heredoc = heredoc_queue.pop(0)

        prev_code = line

    analysis_cache[key] = (exec_lines, alias)
    return analysis_cache[key]

# Sweep through include-dirs so the lcov percentage reflects the total
# source surface, not just the files a test happened to touch.
candidates = set(raw_hits)
for inc in include_dirs:
    if not inc.exists():
        continue
    for path in inc.rglob("*.sh"):
        if not is_skipped(path):
            candidates.add(str(path.resolve()))
    for path in inc.rglob("*"):
        # also include shebanged shell scripts without an extension
        if not path.is_file() or path.suffix or path.stat().st_size == 0:
            continue
        if is_skipped(path):
            continue
        try:
            with open(path, "r", errors="replace") as f:
                first = f.readline()
        except OSError:
            continue
        if first.startswith("#!") and ("bash" in first or "sh" in first):
            candidates.add(str(path.resolve()))

# files[abs_path][line] = hits, restricted to the measurable denominator.
files = {}
for ap in candidates:
    exec_lines, alias = analyze(ap)
    counts = dict.fromkeys(exec_lines, 0)
    for lineno, n_hits in raw_hits.get(ap, {}).items():
        target = alias.get(lineno, lineno)
        if target in counts:
            counts[target] += n_hits
    files[ap] = counts

# Emit lcov.info
with open(out_path, "w") as out:
    for filename in sorted(files):
        out.write(f"SF:{filename}\n")
        for ln in sorted(files[filename]):
            out.write(f"DA:{ln},{files[filename][ln]}\n")
        out.write("end_of_record\n")

# Summary
total_files = len(files)
total_lines = sum(len(lines) for lines in files.values())
covered = sum(1 for lines in files.values() for h in lines.values() if h > 0)
pct = (covered * 100.0 / total_lines) if total_lines else 0.0
print(f"Aggregated: {total_files} files, {covered}/{total_lines} lines = {pct:.2f}%",
      file=sys.stderr)

# Truncation audit. A mangled record is a lost record, so say so. It is a
# hard error only when the lost record could have been for a measured
# file — i.e. its surviving prefix overlaps the repo root. Records for
# paths outside the repo (a $TMPDIR sandbox script, say) never entered
# the denominator, so they are reported without failing the run.
if truncated_records:
    n = sum(truncated_records.values())
    root = str(repo_root)
    fatal = any(root.startswith(p) or p.startswith(root)
                for p in truncated_records)
    level = "error" if fatal else "warning"
    print(f"::{level}::{n} trace record(s) were truncated and could not be "
          f"parsed — bash 3.2 cuts the expanded PS4 at 100 characters",
          file=sys.stderr)
    for name, count in truncated_by_trace.most_common(10):
        print(f"::{level}::truncated records in {name}: {count}", file=sys.stderr)
    for prefix, count in truncated_records.most_common(5):
        print(f"  {count} record(s) truncated at: {prefix!r}", file=sys.stderr)
    print(f"truncated-trace-records: {n} record(s) in "
          f"{len(truncated_by_trace)} trace file(s)", file=sys.stderr)
    if fatal:
        sys.exit(4)
else:
    print("truncated-trace-records: 0", file=sys.stderr)
PY
aggregate_ec=$?

if [[ ! -s "$COVERAGE_OUT" ]]; then
  echo "::error::failed to produce lcov.info — aggregator wrote empty file." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Threshold check.
# -----------------------------------------------------------------------------
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

# Reported last so the coverage number is still visible above it: a killed
# test or a mangled record invalidates the measurement even when the
# surviving tests clear the floor.
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
