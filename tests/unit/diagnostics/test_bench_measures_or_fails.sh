#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# benches/bench.sh exit status is read by the medium_bench_quick_mode
# performance gate, which tolerates exit 1 as "a shell breached its
# threshold". Exit 1 must therefore mean only that. A run that measured
# nothing (hyperfine or jq missing, hyperfine failing) exits 2, so the gate
# can no longer report a 2ms pass for a bench that never ran. Each case runs
# bench.sh on a PATH holding only bash and the shims it names.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BENCH="$REPO_ROOT/benches/bench.sh"
BASH_BIN="$(command -v bash)"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is needed to parse the hyperfine shim's export"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bench-measures.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# hyperfine shim: writes a minimum of BENCH_HF_MIN seconds, or fails without
# an export when BENCH_HF_FAIL is set.
cat >"$WORK/hyperfine" <<'SHIM'
#!/usr/bin/env bash
[[ -n "${BENCH_HF_FAIL:-}" ]] && exit 1
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export-json) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '{"results":[{"summary":{"time_wall_clock":{"min":%s}}}]}\n' "$BENCH_HF_MIN" >"$out"
SHIM
chmod +x "$WORK/hyperfine"

# make_path <name> <tool>...: a bin dir with bash, mktemp, rm and the tools.
make_path() {
  local dir="$WORK/$1" tool
  shift
  mkdir -p "$dir"
  ln -s "$BASH_BIN" "$dir/bash"
  for tool in mktemp rm "$@"; do
    if [[ "$tool" == hyperfine ]]; then
      ln -s "$WORK/hyperfine" "$dir/hyperfine"
    else
      ln -s "$(command -v "$tool")" "$dir/$tool"
    fi
  done
  printf '%s' "$dir"
}

# run_bench <path> [VAR=value...]: prints "<status>|<output>".
run_bench() {
  local path="$1" out rc
  shift
  out="$(env -i HOME="$WORK" PATH="$path" "$@" "$BASH_BIN" "$BENCH" --quick 2>&1 </dev/null)"
  rc=$?
  printf '%s|%s' "$rc" "$out"
}

FULL="$(make_path full hyperfine jq)"

test_start "missing_hyperfine_exits_2"
res="$(run_bench "$(make_path no_hf jq)")"
assert_equals 2 "${res%%|*}" "no hyperfine is not a measurement"
assert_contains "hyperfine" "${res#*|}" "and names the missing tool"

test_start "missing_jq_exits_2"
res="$(run_bench "$(make_path no_jq hyperfine)")"
assert_equals 2 "${res%%|*}" "no jq is not a measurement"
assert_contains "jq" "${res#*|}" "and names the missing tool"

test_start "failed_hyperfine_run_exits_2"
res="$(run_bench "$FULL" BENCH_HF_FAIL=1 BENCH_HF_MIN=0.010)"
assert_equals 2 "${res%%|*}" "a run with no reading is not a pass"
assert_contains "could not measure" "${res#*|}" "and says so"

test_start "non_numeric_reading_exits_2"
res="$(run_bench "$FULL" BENCH_HF_MIN=-0.010)"
assert_equals 2 "${res%%|*}" "a negative time is not a reading"

test_start "under_threshold_exits_0"
res="$(run_bench "$FULL" BENCH_HF_MIN=0.010)"
assert_equals 0 "${res%%|*}" "10ms is under every threshold"
assert_contains "10ms" "${res#*|}" "and reports the reading"

test_start "over_threshold_exits_1"
res="$(run_bench "$FULL" BENCH_HF_MIN=9.000)"
assert_equals 1 "${res%%|*}" "9000ms breaches the bash threshold"
assert_contains "9000ms" "${res#*|}" "and reports the reading"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
