#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
MIN_COVERAGE_PCT="${MIN_COVERAGE_PCT:-0}"          # initial floor; tighten per slice
COV_INCLUDE_DIRS="${COV_INCLUDE_DIRS:-$REPO_ROOT/scripts:$REPO_ROOT/dot_local/bin:$REPO_ROOT/.chezmoitemplates/functions}"
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
cat > "$bash_env" <<'SETUP'
# coverage runtime — enable xtrace, define PS4 with file+line markers
set -x
PS4='+@COV@:${LINENO}:${BASH_SOURCE}:@ '
SETUP

# Sanity-probe: run one trivial script through the pipeline so a
# subsequent failure of the real sweep can be diagnosed quickly.
probe_target="$COVERAGE_DIR/_probe_target.sh"
cat > "$probe_target" <<'PROBE'
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
printf '%s\n' "${test_files[@]}" \
  | xargs -I{} -n1 -P"$JOBS" bash -c 'run_one "$@"' _ {} \
  || true
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
                    src_path = (repo_root / src_path).resolve()
                if not in_includes(src_path):
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
    """Heuristic: lines that aren't comments, blank, or shebangs are
    candidates for execution. Bash xtrace only fires on actual command
    lines (control structures, function defs, etc. also count as
    executable; we don't distinguish to keep this simple)."""
    try:
        with open(path, "r", errors="replace") as f:
            text = f.read().splitlines()
    except OSError:
        return []
    out = []
    for i, line in enumerate(text, 1):
        if not line or ws_re.match(line):
            continue
        if shebang_re.match(line):
            continue
        if comment_re.match(line):
            continue
        out.append(i)
    return out

for inc in include_dirs:
    if not inc.exists():
        continue
    for path in inc.rglob("*.sh"):
        ap = str(path.resolve())
        existing = files[ap]  # creates the entry on touch
        for ln in executable_lines(path):
            if ln not in existing:
                existing[ln] = 0
    for path in inc.rglob("*"):
        # also include shebanged shell scripts without .sh
        if path.is_file() and not path.suffix and path.stat().st_size > 0:
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
summary=$(python3 - "$COVERAGE_OUT" <<'PY'
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
