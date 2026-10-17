#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# benches/dot_command_bench.sh records each command's median from hyperfine's
# export. hyperfine 2.x moved the statistics under summary.time_wall_clock;
# reading the 1.x field there gave null, so every case recorded -1. A shim
# hyperfine writes either schema and the recorded medians are checked.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BENCH="$REPO_ROOT/benches/dot_command_bench.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is needed for the hyperfine path"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-cmd-bench.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

# hyperfine shim: writes a median of 42ms in the schema BENCH_HF_SCHEMA names.
cat >"$WORK/bin/hyperfine" <<'SHIM'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export-json) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ "${BENCH_HF_SCHEMA:-1}" == "2" ]]; then
  printf '{"results":[{"summary":{"time_wall_clock":{"unit":"second","median":0.042}}}]}\n' >"$out"
else
  printf '{"results":[{"median":0.042}]}\n' >"$out"
fi
SHIM
chmod +x "$WORK/bin/hyperfine"

# run_bench <schema>: prints "<cases>|<cases at 42ms>|<cases at -1>".
run_bench() {
  local json="$WORK/out-$1.json"
  BENCH_HF_SCHEMA="$1" PATH="$WORK/bin:$PATH" \
    bash "$BENCH" --help-only --runs 1 --output "$json" >/dev/null 2>&1 </dev/null
  printf '%s|%s|%s' \
    "$(jq '.cases | length' "$json" 2>/dev/null)" \
    "$(jq '[.cases[] | select(.median_ms == 42)] | length' "$json" 2>/dev/null)" \
    "$(jq '[.cases[] | select(.median_ms == -1)] | length' "$json" 2>/dev/null)"
}

for schema in 1 2; do
  test_start "median_read_from_hyperfine_${schema}x_export"
  IFS='|' read -r total at42 failed <<<"$(run_bench "$schema")"
  assert_equals "yes" "$([[ "${total:-0}" -gt 0 ]] && echo yes || echo no)" "the sweep recorded cases"
  assert_equals "$total|0" "$at42|$failed" "every case records the 42ms median, none -1"
done

print_summary
