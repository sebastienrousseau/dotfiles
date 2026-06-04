#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
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
# Linux + macOS both work (macOS bash 3.2 supports BASH_XTRACEFD as
# well — verified locally on bash 5.3 via Homebrew). The pre-commit
# hook in this repo can invoke this on any platform.
#
# Closes the runner half of #856 / Slice 1 of #883.
# =============================================================================

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TESTS_DIR="${TESTS_DIR:-$REPO_ROOT/tests}"
COVERAGE_DIR="${COVERAGE_DIR:-$REPO_ROOT/coverage}"
COVERAGE_OUT="${COVERAGE_OUT:-$COVERAGE_DIR/lcov.info}"
MIN_COVERAGE_PCT="${MIN_COVERAGE_PCT:-0}" # initial floor; tighten per slice
COV_INCLUDE_DIRS="${COV_INCLUDE_DIRS:-$REPO_ROOT/scripts:$REPO_ROOT/defaults/dot_local/bin:$REPO_ROOT/defaults/.chezmoitemplates/functions}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
COV_TEST_TIMEOUT="${COV_TEST_TIMEOUT:-60}"

mkdir -p "$COVERAGE_DIR"
trace_dir="$COVERAGE_DIR/traces"
rm -rf "$trace_dir"
mkdir -p "$trace_dir"

# -----------------------------------------------------------------------------
# BASH_ENV setup file: enables xtrace in every non-interactive bash that
# inherits it. Child processes spawned via `bash $SCRIPT` get their own
# tracing turned on automatically.
# -----------------------------------------------------------------------------
bash_env="$COVERAGE_DIR/_cov_bashenv.sh"
cat >"$bash_env" <<'SETUP'
# coverage runtime — enable xtrace, define PS4 with file+line markers.
# `${BASH_SOURCE:-}` (not `${BASH_SOURCE}`) prevents PS4 evaluation
# from failing under `set -u`: at the top level of a `bash -c`
# script, BASH_SOURCE[0] is unbound; an unguarded expansion under
# `set -u` aborts the shell, taking out any test that sources a
# `set -euo pipefail` library file.
set -x
PS4='+@COV@:${LINENO}:${BASH_SOURCE:-}:@ '
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

PS4='+@COV@:${LINENO}:${BASH_SOURCE}:@ ' \
  BASH_ENV="$bash_env" \
  bash "$probe_target" 2>"$trace_dir/_probe.trace" >/dev/null || true
probe_lines=$(grep -cE "^\+@COV@:[0-9]+:.*${probe_target}:@" "$trace_dir/_probe.trace" 2>/dev/null || echo 0)
echo "probe: ${probe_lines} traced lines from ${probe_target}" >&2
if [[ "$probe_lines" -eq 0 ]]; then
  echo "::error::xtrace probe captured no lines — coverage mechanism broken" >&2
  exit 2
fi

# -----------------------------------------------------------------------------
# Collect test files (mirror tests/framework/test_runner.sh discovery).
# -----------------------------------------------------------------------------
mapfile -t test_files < <(find "$TESTS_DIR/unit" -name 'test_*.sh' -type f | sort)

if [[ "${#test_files[@]}" -eq 0 ]]; then
  echo "::error::no unit test files discovered under $TESTS_DIR/unit" >&2
  exit 1
fi

echo "Tracing ${#test_files[@]} test files (parallel × $JOBS, timeout ${COV_TEST_TIMEOUT}s/test)..." >&2

# -----------------------------------------------------------------------------
# Worker function — runs one test under xtrace, captures stderr.
# -----------------------------------------------------------------------------
# shellcheck disable=SC2329  # called indirectly via xargs subshell
run_one() {
  local f="$1"
  local trace
  trace="$COV_TRACE_DIR/$(basename "$f" .sh).trace"
  PS4='+@COV@:${LINENO}:${BASH_SOURCE}:@ ' \
    BASH_ENV="$COV_BASH_ENV" \
    timeout --kill-after=5 "$COV_TEST_TIMEOUT" \
    bash "$f" 2>"$trace" >/dev/null || true
}

export COV_TRACE_DIR="$trace_dir"
export COV_BASH_ENV="$bash_env"
export COV_TEST_TIMEOUT
export -f run_one

start_ts=$(date +%s)
printf '%s\n' "${test_files[@]}" |
  xargs -I{} -n1 -P"$JOBS" bash -c 'run_one "$@"' _ {} ||
  true
elapsed=$(($(date +%s) - start_ts))
echo "trace phase done in ${elapsed}s" >&2

# -----------------------------------------------------------------------------
# Aggregate trace files → lcov.info.
# -----------------------------------------------------------------------------
python3 - "$COVERAGE_OUT" "$trace_dir" "$REPO_ROOT" "$COV_INCLUDE_DIRS" <<'PY'
"""Aggregate bash xtrace output into lcov.info."""
import os
import re
import sys
from collections import defaultdict
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

# Pattern: +@COV@:<lineno>:<source>:@
hit_re = re.compile(r"^\+@COV@:(\d+):([^:]+):@")

# files[abs_path][line] = total hits
files = defaultdict(lambda: defaultdict(int))

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

# Parse every trace file. Each trace can be MBs; iterate line by line.
for trace_path in sorted(trace_dir.glob("*.trace")):
    try:
        with open(trace_path, "r", errors="replace") as f:
            for line in f:
                m = hit_re.match(line)
                if not m:
                    continue
                lineno = int(m.group(1))
                src = m.group(2).strip()
                if not src or src == "main":
                    continue
                src_path = Path(src)
                if not src_path.is_absolute():
                    src_path = (repo_root / src_path)
                # Always resolve so `..`-style paths from inside
                # `commands/foo.sh` sourcing `../lib/log.sh` collapse
                # to the same canonical SF: key as a direct hit on
                # `lib/log.sh`. Without this we get three SF: blocks
                # for one file and the denominator inflates.
                try:
                    src_path = src_path.resolve()
                except (OSError, RuntimeError):
                    pass
                if not in_includes(src_path):
                    continue
                if is_skipped(src_path):
                    continue
                files[str(src_path)][lineno] += 1
    except OSError as e:
        print(f"warn: read error {trace_path}: {e}", file=sys.stderr)

# Sweep through include-dirs and add executable lines for files we never
# touched, so lcov coverage % reflects total source surface, not just
# touched files.
ws_re = re.compile(r"^\s*$")
comment_re = re.compile(r"^\s*#")
shebang_re = re.compile(r"^\s*#!")

def executable_lines(path: Path):
    """Lines that bash xtrace can plausibly emit.

    Excludes:
      - blanks / shebangs / comments (already)
      - structural-only keywords (`fi`, `done`, `else`, `esac`, `then`,
        `do`, `in`, bare `{`/`}` braces) — these are syntax, not
        commands; xtrace never traces them
      - heredoc body lines (between `<<EOF` and `EOF`) — content, not
        executed
      - `case` pattern labels (`foo)`) — the matched body executes,
        not the pattern itself

    This matches what `bash -x` actually produces a `+`-prefixed
    line for, so the denominator reflects measurable lines.

    Honor LCOV_EXCL_LINE / LCOV_EXCL_START / LCOV_EXCL_STOP markers
    so authors can exempt genuinely unreachable lines (platform-
    gated branches, root-only paths, dead-code stubs).
    """
    import re as _re
    structural = _re.compile(
        r"^\s*("
        r"fi|done|else|elif|esac|then|do|in|"
        r"\}|\{|"
        r"\)\s*;?;?\s*$|"        # bare `)` (case pattern close)
        r";;\s*$"                # `;;` case-clause terminator
        r")\s*(#.*)?$"
    )
    case_pattern = _re.compile(r"^\s*[a-zA-Z0-9_\*\?\[\|/\-\.+]+\)\s*(#.*)?$")
    heredoc_open = _re.compile(r"<<-?\s*[\"\']?([A-Za-z_][A-Za-z0-9_]*)[\"\']?")
    excl_line = _re.compile(r"#\s*LCOV_EXCL_LINE")
    excl_start = _re.compile(r"#\s*LCOV_EXCL_START")
    excl_stop = _re.compile(r"#\s*LCOV_EXCL_STOP")
    # Scripts that explicitly turn off xtrace can't be measured by
    # this mechanism — the bash runtime simply stops emitting trace
    # records. Treat everything after `set +x` / `set +o xtrace`
    # as excluded so it doesn't sink the denominator.
    xtrace_off = _re.compile(r"^\s*set\s+(\+x|\+o\s+xtrace)\b")

    try:
        with open(path, "r", errors="replace") as f:
            text = f.read().splitlines()
    except OSError:
        return []

    out = []
    in_heredoc = None  # the terminator we're waiting for
    excluding = False
    xtrace_disabled = False
    for i, line in enumerate(text, 1):
        # LCOV_EXCL handling
        if excl_start.search(line):
            excluding = True
            continue
        if excl_stop.search(line):
            excluding = False
            continue
        if excluding:
            continue
        if excl_line.search(line):
            continue

        # Once a script disables xtrace, no further lines can be
        # measured by this mechanism — drop them from the denominator.
        if xtrace_disabled:
            continue
        if xtrace_off.match(line):
            xtrace_disabled = True
            continue

        # Heredoc body — track and skip
        if in_heredoc is not None:
            if line.strip() == in_heredoc:
                in_heredoc = None
            continue
        hd = heredoc_open.search(line)
        if hd and not comment_re.match(line):
            in_heredoc = hd.group(1)

        if not line or ws_re.match(line):
            continue
        if shebang_re.match(line):
            continue
        if comment_re.match(line):
            continue
        if structural.match(line):
            continue
        if case_pattern.match(line):
            continue
        out.append(i)
    return out

for inc in include_dirs:
    if not inc.exists():
        continue
    for path in inc.rglob("*.sh"):
        if is_skipped(path):
            continue
        ap = str(path.resolve())
        existing = files[ap]  # creates the entry on touch
        for ln in executable_lines(path):
            if ln not in existing:
                existing[ln] = 0
    for path in inc.rglob("*"):
        # also include shebanged shell scripts without .sh
        if path.is_file() and not path.suffix and path.stat().st_size > 0:
            if is_skipped(path):
                continue
            try:
                with open(path, "r", errors="replace") as f:
                    first = f.readline()
            except OSError:
                continue
            if first.startswith("#!") and ("bash" in first or "sh" in first):
                ap = str(path.resolve())
                existing = files[ap]
                for ln in executable_lines(path):
                    if ln not in existing:
                        existing[ln] = 0

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
PY

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

exit 0
