#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# run-coverage.sh — Bash code-coverage runner. Wraps every test file
# under tests/unit/ with kcov (in parallel) and aggregates the per-test
# Cobertura reports into a single lcov.info at $COVERAGE_OUT.
#
# Why per-file aggregation (and not `kcov --merge`):
#   kcov --merge emits varied directory layouts across versions and
#   sometimes silently drops the merged Cobertura artifact when the
#   set of inputs grows large. We read each per-test cobertura.xml
#   directly and aggregate hits in Python — deterministic, no
#   merge-format guessing.
#
# Why parallel + per-test timeout:
#   kcov's bash backend uses ptrace + hardware breakpoints (requires
#   bash-dbgsym on Ubuntu 24.04+). Real instrumentation makes each
#   test 3-10x slower than a raw run, so serial 447-test execution
#   blew past GitHub's 30-min workflow budget. We fan out across
#   $JOBS workers and hard-cap each wrapping at $KCOV_TEST_TIMEOUT
#   seconds so a single hung test can't sink the whole run.
#
# Linux-only (kcov on macOS reports "no debug symbols" for bash and
# yields 0% — a known upstream limitation). Skips gracefully on
# Darwin so the same script can be invoked from the parallel
# pre-commit hook on developer boxes.
#
# Closes the runner half of #856.
# =============================================================================

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TESTS_DIR="${TESTS_DIR:-$REPO_ROOT/tests}"
COVERAGE_DIR="${COVERAGE_DIR:-$REPO_ROOT/coverage}"
COVERAGE_OUT="${COVERAGE_OUT:-$COVERAGE_DIR/lcov.info}"
MIN_COVERAGE_PCT="${MIN_COVERAGE_PCT:-0}"      # initial floor; tighten with each slice
KCOV_INCLUDE_PATH="${KCOV_INCLUDE_PATH:-$REPO_ROOT/scripts,$REPO_ROOT/.chezmoitemplates/functions,$REPO_ROOT/dot_local/bin}"
KCOV_EXCLUDE_PATH="${KCOV_EXCLUDE_PATH:-$TESTS_DIR}"
KCOV_EXCLUDE_PATTERN="${KCOV_EXCLUDE_PATTERN:-/\.git/,/node_modules/}"
# Tell kcov upfront which directories contain bash scripts it should
# parse for coverage. Without this, kcov only sees scripts that are
# directly invoked, and misses scripts called as subprocesses from
# tests.
KCOV_PARSE_DIRS="${KCOV_PARSE_DIRS:-$REPO_ROOT/scripts,$REPO_ROOT/dot_local/bin}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
KCOV_TEST_TIMEOUT="${KCOV_TEST_TIMEOUT:-60}"

# Skip cleanly on macOS so the local-dev invocation doesn't blow up.
case "$(uname -s)" in
  Linux) ;;
  *)
    echo "::warning::run-coverage.sh skipped — kcov requires Linux (got $(uname -s))." >&2
    exit 0
    ;;
esac

if ! command -v kcov >/dev/null 2>&1; then
  echo "::error::kcov not found on PATH. apt-get install -y kcov on Ubuntu." >&2
  exit 2
fi

KCOV_BIN="$(command -v kcov)"
echo "kcov: $KCOV_BIN ($(kcov --version 2>&1 | head -1))" >&2
echo "include-path: $KCOV_INCLUDE_PATH" >&2
echo "exclude-path: $KCOV_EXCLUDE_PATH" >&2
echo "jobs: $JOBS / per-test timeout: ${KCOV_TEST_TIMEOUT}s" >&2

mkdir -p "$COVERAGE_DIR"
rm -rf "$COVERAGE_DIR"/*.kcov 2>/dev/null || true

# -----------------------------------------------------------------------------
# Probe: validate the chosen kcov flags actually capture bash-script
# coverage of a real repo script before running 447 tests. Fast (~2s)
# and gives a sharp signal of whether `--bash-parse-files-in-dir`
# wires through correctly.
echo "── probe: validate-chezmoidata.sh with chosen flags ──" >&2
rm -rf "$COVERAGE_DIR/_probe_real"
"$KCOV_BIN" \
  --bash-parse-files-in-dir="$KCOV_PARSE_DIRS" \
  --include-path="$KCOV_INCLUDE_PATH" \
  --exclude-path="$KCOV_EXCLUDE_PATH" \
  "$COVERAGE_DIR/_probe_real" \
  bash "$REPO_ROOT/scripts/ci/validate-chezmoidata.sh" >/dev/null 2>&1 || true
probe_cob=$(find "$COVERAGE_DIR/_probe_real" -name 'cobertura.xml' 2>/dev/null | head -1)
if [[ -n "$probe_cob" ]]; then
  probe_classes=$(grep -c '<class ' "$probe_cob" 2>/dev/null || echo 0)
  echo "  probe[real_with_parse_dirs] classes=$probe_classes" >&2
  if [[ "$probe_classes" -gt 0 ]]; then
    echo "  first <class> filenames:" >&2
    grep -oE 'filename="[^"]*"' "$probe_cob" | head -8 >&2
  fi
fi

# -----------------------------------------------------------------------------
# Collect test files (mirror tests/framework/test_runner.sh discovery).
# -----------------------------------------------------------------------------
mapfile -t test_files < <(find "$TESTS_DIR/unit" -name 'test_*.sh' -type f | sort)

if [[ "${#test_files[@]}" -eq 0 ]]; then
  echo "::error::no unit test files discovered under $TESTS_DIR/unit" >&2
  exit 1
fi

echo "Wrapping ${#test_files[@]} test files with kcov (parallel × $JOBS)..." >&2

# -----------------------------------------------------------------------------
# Worker function — runs one test under kcov with a hard wall-time cap.
# Exits 0 on success, 124 on timeout, other on kcov error.
# Each invocation isolates its own out-dir so workers don't race.
# -----------------------------------------------------------------------------
# shellcheck disable=SC2329  # called indirectly via xargs subshell
run_one() {
  local f="$1"
  local rel="${f#"$REPO_ROOT/"}"
  local out_dir
  out_dir="$COVERAGE_DIR/$(basename "$f" .sh).kcov"
  if timeout --kill-after=5 "$KCOV_TEST_TIMEOUT" \
       "$KCOV_BIN" \
         --bash-parse-files-in-dir="$KCOV_PARSE_DIRS" \
         --include-path="$KCOV_INCLUDE_PATH" \
         --exclude-path="$KCOV_EXCLUDE_PATH" \
         --exclude-pattern="$KCOV_EXCLUDE_PATTERN" \
         "$out_dir" \
         bash "$f" >/dev/null 2>&1; then
    return 0
  else
    rc=$?
    echo "  ✗ $rel (rc=$rc)" >&2
    return "$rc"
  fi
}

# Export so xargs subshells can call run_one.
export REPO_ROOT COVERAGE_DIR KCOV_BIN KCOV_INCLUDE_PATH KCOV_EXCLUDE_PATH \
       KCOV_EXCLUDE_PATTERN KCOV_PARSE_DIRS KCOV_TEST_TIMEOUT
export -f run_one

# Fan out with xargs. We accept partial failures (some tests legitimately
# fail under kcov instrumentation due to ptrace ordering); the aggregate
# step downstream reports whatever coverage was captured.
start_ts=$(date +%s)
printf '%s\n' "${test_files[@]}" \
  | xargs -I{} -n1 -P"$JOBS" bash -c 'run_one "$@"' _ {} \
  || true
elapsed=$(($(date +%s) - start_ts))
echo "kcov wrap phase done in ${elapsed}s" >&2

# -----------------------------------------------------------------------------
# Diagnostic: count populated cobertura.xml outputs.
# -----------------------------------------------------------------------------
mapfile -t cobertura_files < <(find "$COVERAGE_DIR" -path '*.kcov/*/cobertura.xml' 2>/dev/null)
nonempty=0
sample=""
for cob in "${cobertura_files[@]}"; do
  if grep -q '<class ' "$cob" 2>/dev/null; then
    nonempty=$((nonempty + 1))
    [[ -z "$sample" ]] && sample="$cob"
  fi
done
echo "${#cobertura_files[@]} cobertura.xml files; $nonempty have non-empty <class> entries" >&2
[[ -n "$sample" ]] && echo "sample non-empty: $sample" >&2

if [[ "${#cobertura_files[@]}" -eq 0 ]]; then
  echo "::error::no cobertura.xml outputs produced by kcov" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Aggregate per-test cobertura.xml into a single lcov.info.
# -----------------------------------------------------------------------------
python3 - "$COVERAGE_OUT" "${cobertura_files[@]}" <<'PY'
"""Aggregate kcov Cobertura outputs into a single lcov.info."""
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

out_path = sys.argv[1]
inputs = sys.argv[2:]

# files[filename][line] = max hits seen across runs. Max is sufficient
# for line coverage (covered vs not). Sum would inflate the count.
files = defaultdict(lambda: defaultdict(int))

for path in inputs:
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        print(f"warn: parse error in {path}: {exc}", file=sys.stderr)
        continue
    for cls in root.iter("class"):
        filename = cls.get("filename") or ""
        if not filename:
            continue
        for line in cls.iter("line"):
            ln_attr = line.get("number")
            hits = int(line.get("hits", "0"))
            if ln_attr is None:
                continue
            ln = int(ln_attr)
            if hits > files[filename][ln]:
                files[filename][ln] = hits

with open(out_path, "w") as f:
    for filename in sorted(files):
        f.write(f"SF:{filename}\n")
        for ln in sorted(files[filename]):
            f.write(f"DA:{ln},{files[filename][ln]}\n")
        f.write("end_of_record\n")

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
