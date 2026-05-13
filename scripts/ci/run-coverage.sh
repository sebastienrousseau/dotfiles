#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# run-coverage.sh — Bash code-coverage runner. Wraps every test file
# under tests/unit/ with kcov and aggregates the per-test Cobertura
# reports into a single lcov.info at $COVERAGE_OUT.
#
# Why per-file aggregation (and not `kcov --merge`):
#   kcov --merge emits varied directory layouts across versions and
#   sometimes silently drops the merged Cobertura artifact when the
#   set of inputs grows large (we saw 0/0 on 445 inputs in CI). We
#   read each per-test cobertura.xml directly and sum line hits in
#   Python — deterministic, no merge-format guessing.
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
MIN_COVERAGE_PCT="${MIN_COVERAGE_PCT:-50}"     # initial floor; tighten over time
KCOV_INCLUDE_PATH="${KCOV_INCLUDE_PATH:-$REPO_ROOT/scripts,$REPO_ROOT/.chezmoitemplates/functions,$REPO_ROOT/dot_local/bin}"
KCOV_EXCLUDE_PATH="${KCOV_EXCLUDE_PATH:-$TESTS_DIR}"
KCOV_EXCLUDE_PATTERN="${KCOV_EXCLUDE_PATTERN:-/\.git/,/node_modules/}"
DEBUG_COVERAGE="${DEBUG_COVERAGE:-0}"

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

echo "kcov version: $(kcov --version 2>&1 | head -1)" >&2
echo "include-path: $KCOV_INCLUDE_PATH" >&2
echo "exclude-path: $KCOV_EXCLUDE_PATH" >&2

mkdir -p "$COVERAGE_DIR"
rm -rf "$COVERAGE_DIR"/*.kcov 2>/dev/null || true

# -----------------------------------------------------------------------------
# Collect test files (mirror tests/framework/test_runner.sh discovery).
# -----------------------------------------------------------------------------
mapfile -t test_files < <(find "$TESTS_DIR/unit" -name 'test_*.sh' -type f | sort)

if [[ "${#test_files[@]}" -eq 0 ]]; then
  echo "::error::no unit test files discovered under $TESTS_DIR/unit" >&2
  exit 1
fi

echo "Wrapping ${#test_files[@]} test files with kcov..." >&2

passed=0
failed=0
first=1
for f in "${test_files[@]}"; do
  rel="${f#"$REPO_ROOT/"}"
  out_dir="$COVERAGE_DIR/$(basename "$f" .sh).kcov"
  # Capture kcov stderr for the first run so we can see what kcov is
  # doing. Suppress for subsequent runs to keep logs readable.
  if [[ "$first" == "1" ]]; then
    echo "── first kcov run (verbose): $rel ──" >&2
    if kcov \
        --include-path="$KCOV_INCLUDE_PATH" \
        --exclude-path="$KCOV_EXCLUDE_PATH" \
        --exclude-pattern="$KCOV_EXCLUDE_PATTERN" \
        "$out_dir" \
        bash "$f" 2>&1 | tail -20 >&2; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
      echo "  ✗ $rel" >&2
    fi
    first=0
  else
    if kcov \
        --include-path="$KCOV_INCLUDE_PATH" \
        --exclude-path="$KCOV_EXCLUDE_PATH" \
        --exclude-pattern="$KCOV_EXCLUDE_PATTERN" \
        "$out_dir" \
        bash "$f" >/dev/null 2>&1; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
      echo "  ✗ $rel" >&2
    fi
  fi
done

echo "kcov runs: $passed passed, $failed failed" >&2

# -----------------------------------------------------------------------------
# Diagnostic: find any cobertura.xml with non-empty classes so we can
# see what kcov actually managed to instrument. Also report which tests
# produced any class data at all.
# -----------------------------------------------------------------------------
nonempty=0
sample_nonempty=""
while IFS= read -r cob; do
  if grep -q '<class ' "$cob" 2>/dev/null; then
    nonempty=$((nonempty + 1))
    [[ -z "$sample_nonempty" ]] && sample_nonempty="$cob"
  fi
done < <(find "$COVERAGE_DIR" -path '*.kcov/*/cobertura.xml')

echo "── diagnostic: $nonempty / 447 cobertura.xml files have non-empty <class> entries ──" >&2

if [[ -n "$sample_nonempty" ]]; then
  echo "── diagnostic: head of non-empty sample $sample_nonempty ──" >&2
  head -30 "$sample_nonempty" >&2
fi

# Always show the first test's cobertura too so we know what an empty
# one looks like.
first_kcov=$(find "$COVERAGE_DIR" -maxdepth 1 -name '*.kcov' -type d | sort | head -1)
if [[ -n "$first_kcov" ]]; then
  echo "── diagnostic: alphabetically-first kcov dir contents ──" >&2
  find "$first_kcov" -type f | head -10 >&2
fi

# Triage the empty-output case with three orthogonal kcov invocations.
# If ALL of these come back empty, the issue is kcov itself or env;
# if some come back populated, the issue is in our test wrapping.
KCOV_BIN="$(command -v kcov)"
echo "── diagnostic: kcov binary = $KCOV_BIN ──" >&2

# Probe 1: direct script invocation, default method, full filters.
echo "── probe 1: direct kcov on validate-chezmoidata.sh (defaults) ──" >&2
rm -rf "$COVERAGE_DIR/_probe1.kcov"
"$KCOV_BIN" \
  --include-path="$KCOV_INCLUDE_PATH" \
  --exclude-path="$KCOV_EXCLUDE_PATH" \
  "$COVERAGE_DIR/_probe1.kcov" \
  bash "$REPO_ROOT/scripts/ci/validate-chezmoidata.sh" 2>&1 >/dev/null | head -10 >&2 || true
probe1_cob=$(find "$COVERAGE_DIR/_probe1.kcov" -name 'cobertura.xml' 2>/dev/null | head -1)
[[ -n "$probe1_cob" ]] && echo "  probe1 classes: $(grep -c '<class ' "$probe1_cob" 2>/dev/null || echo 0)" >&2

# Probe 2: direct script invocation, DEBUG method (no PS4 rewriting).
echo "── probe 2: --bash-method=DEBUG on validate-chezmoidata.sh ──" >&2
rm -rf "$COVERAGE_DIR/_probe2.kcov"
"$KCOV_BIN" \
  --bash-method=DEBUG \
  --include-path="$KCOV_INCLUDE_PATH" \
  --exclude-path="$KCOV_EXCLUDE_PATH" \
  "$COVERAGE_DIR/_probe2.kcov" \
  bash "$REPO_ROOT/scripts/ci/validate-chezmoidata.sh" 2>&1 >/dev/null | head -10 >&2 || true
probe2_cob=$(find "$COVERAGE_DIR/_probe2.kcov" -name 'cobertura.xml' 2>/dev/null | head -1)
[[ -n "$probe2_cob" ]] && echo "  probe2 classes: $(grep -c '<class ' "$probe2_cob" 2>/dev/null || echo 0)" >&2

# Probe 3: NO include-path filter at all. Surfaces whether kcov is
# producing data that the filter is rejecting.
echo "── probe 3: no include filter on validate-chezmoidata.sh ──" >&2
rm -rf "$COVERAGE_DIR/_probe3.kcov"
"$KCOV_BIN" \
  --exclude-path="$KCOV_EXCLUDE_PATH" \
  "$COVERAGE_DIR/_probe3.kcov" \
  bash "$REPO_ROOT/scripts/ci/validate-chezmoidata.sh" 2>&1 >/dev/null | head -10 >&2 || true
probe3_cob=$(find "$COVERAGE_DIR/_probe3.kcov" -name 'cobertura.xml' 2>/dev/null | head -1)
if [[ -n "$probe3_cob" ]]; then
  echo "  probe3 classes: $(grep -c '<class ' "$probe3_cob" 2>/dev/null || echo 0)" >&2
  echo "  probe3 head:" >&2
  head -40 "$probe3_cob" >&2
fi

# -----------------------------------------------------------------------------
# Aggregate every per-test cobertura.xml into a single lcov.info.
# Sum hits across runs for the same file:line.
# -----------------------------------------------------------------------------
mapfile -t cobertura_files < <(find "$COVERAGE_DIR" -path '*.kcov/*/cobertura.xml' 2>/dev/null)
echo "Found ${#cobertura_files[@]} cobertura.xml files to aggregate" >&2

if [[ "${#cobertura_files[@]}" -eq 0 ]]; then
  echo "::error::no cobertura.xml outputs produced by kcov" >&2
  exit 1
fi

python3 - "$COVERAGE_OUT" "${cobertura_files[@]}" <<'PY'
"""Aggregate kcov Cobertura outputs into a single lcov.info."""
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

out_path = sys.argv[1]
inputs = sys.argv[2:]

# files[filename][line] = max(hits)  — kcov hits are already counts, so
# taking the max across runs is conservative; sum would also work, but
# max is sufficient for line coverage (covered vs not).
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
            ln = line.get("number")
            hits = int(line.get("hits", "0"))
            if ln is None:
                continue
            ln = int(ln)
            if hits > files[filename][ln]:
                files[filename][ln] = hits

with open(out_path, "w") as f:
    for filename in sorted(files):
        f.write(f"SF:{filename}\n")
        for ln in sorted(files[filename]):
            f.write(f"DA:{ln},{files[filename][ln]}\n")
        f.write("end_of_record\n")

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
# Threshold check (same logic as the CI gate, kept here so the script
# fails locally too).
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

# Float compare via awk for portability (bash arithmetic is integer-only).
below=$(awk -v p="$pct" -v t="$MIN_COVERAGE_PCT" 'BEGIN{print (p+0 < t+0) ? "1" : "0"}')
if [[ "$below" == "1" ]]; then
  echo "::error::coverage ${pct}% is below the floor ${MIN_COVERAGE_PCT}%" >&2
  exit 1
fi

exit 0
