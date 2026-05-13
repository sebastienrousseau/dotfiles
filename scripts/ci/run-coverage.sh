#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# run-coverage.sh — Bash code-coverage runner. Wraps every test file
# under tests/unit/ with kcov, merges the per-file reports, and emits a
# single lcov.info at $COVERAGE_OUT (default: coverage/lcov.info).
#
# Linux-only (kcov on macOS requires private-API workarounds). Skips
# gracefully on macOS so the same script can be invoked from the
# parallel pre-commit hook on developer boxes.
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
for f in "${test_files[@]}"; do
  rel="${f#"$REPO_ROOT/"}"
  out_dir="$COVERAGE_DIR/$(basename "$f" .sh).kcov"
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
done

echo "kcov runs: $passed passed, $failed failed" >&2

# -----------------------------------------------------------------------------
# Merge per-file kcov runs into a single lcov.info.
# kcov writes <out>/bash.<hash>/coverage.json + cobertura.xml + a
# merged kcov-merged dir if invoked with --merge. Easiest portable
# path: re-invoke kcov --merge to get a single output, then convert.
# -----------------------------------------------------------------------------
merged_dir="$COVERAGE_DIR/merged"
rm -rf "$merged_dir"
kcov --merge "$merged_dir" "$COVERAGE_DIR"/*.kcov >/dev/null 2>&1 || true

# kcov emits an lcov-compatible info file at <merged>/kcov-merged/index.json
# but the canonical lcov.info comes from <merged>/<single>/coverage.json's
# sibling. Easier: walk the merged directory for any .info file.
found_lcov=$(find "$merged_dir" -name 'lcov.info' -o -name 'coverage.lcov' 2>/dev/null | head -1)
if [[ -n "$found_lcov" ]]; then
  cp "$found_lcov" "$COVERAGE_OUT"
else
  # Newer kcov versions (>=43) write cobertura but not lcov by default;
  # synthesize lcov from cobertura.xml so Codecov can ingest it.
  cobertura="$merged_dir/cobertura.xml"
  if [[ ! -f "$cobertura" ]]; then
    cobertura=$(find "$merged_dir" -name 'cobertura.xml' 2>/dev/null | head -1)
  fi
  if [[ -n "$cobertura" && -f "$cobertura" ]]; then
    python3 - "$cobertura" "$COVERAGE_OUT" <<'PY'
"""Minimal Cobertura → lcov converter. Handles the subset kcov emits."""
import sys, xml.etree.ElementTree as ET
src, dst = sys.argv[1], sys.argv[2]
root = ET.parse(src).getroot()
out_lines = []
for pkg in root.iter("package"):
    for cls in pkg.iter("class"):
        filename = cls.get("filename") or ""
        if not filename:
            continue
        out_lines.append(f"SF:{filename}")
        for line in cls.iter("line"):
            ln = line.get("number")
            hits = line.get("hits", "0")
            out_lines.append(f"DA:{ln},{hits}")
        out_lines.append("end_of_record")
with open(dst, "w") as f:
    f.write("\n".join(out_lines) + "\n")
PY
  fi
fi

if [[ ! -s "$COVERAGE_OUT" ]]; then
  echo "::error::failed to produce lcov.info — no kcov output found." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Summary + threshold check.
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

# Threshold guard — fails the job on a regression below MIN_COVERAGE_PCT.
# Float compare via awk for portability (bash arithmetic is integer-only).
below=$(awk -v p="$pct" -v t="$MIN_COVERAGE_PCT" 'BEGIN{print (p+0 < t+0) ? "1" : "0"}')
if [[ "$below" == "1" ]]; then
  echo "::error::coverage ${pct}% is below the floor ${MIN_COVERAGE_PCT}%" >&2
  exit 1
fi

exit 0
