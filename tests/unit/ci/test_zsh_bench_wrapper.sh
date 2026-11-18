#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# benches/zsh-bench.sh wraps romkatv/zsh-bench for the perf-baseline gate:
# it reduces `zsh-bench --raw` output to medians, compares them with a
# baseline (percentage AND absolute floor), and runs zsh-bench only from a
# tarball whose SHA-256 matches the pin. No case reaches the network: curl
# is a stub.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BENCH="${ZSH_BENCH_WRAPPER:-$REPO_ROOT/benches/zsh-bench.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

summarize() { printf '%b' "$1" | bash "$BENCH" summarize; }
json_get() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1]))' "$1"; }

# ── summarize ───────────────────────────────────────────────────────────
test_start "summarize_takes_the_median_of_raw_iterations"
out="$(summarize 'creates_tty=( 0 0 0 )\nfirst_prompt_lag_ms=( 30.5 10.25 20.0 )\nfirst_command_lag_ms=( 5 9 7 6 )\n')"
assert_equals "20.0" "$(json_get first_prompt_lag_ms <<<"$out")" "odd count: the middle value"
assert_equals "6.5" "$(json_get first_command_lag_ms <<<"$out")" "even count: the mean of the two middle values"
assert_equals "3" "$(json_get iters <<<"$out")" "iterations counted"
assert_equals "None" "$(json_get creates_tty <<<"$out")" "non-latency fields are not reported"

# ── compare ─────────────────────────────────────────────────────────────
printf '{"first_prompt_lag_ms": 100, "first_command_lag_ms": 40}\n' >"$WORK/base.json"
compare() {
  printf '%s\n' "$1" >"$WORK/cur.json"
  RC=0
  OUT="$(bash "$BENCH" compare "$WORK/cur.json" "$WORK/base.json" 2>&1)" || RC=$?
}

test_start "compare_passes_within_the_threshold"
compare '{"first_prompt_lag_ms": 124, "first_command_lag_ms": 54}'
assert_equals "0" "$RC" "+24% prompt, +14 ms command: within limits"

test_start "compare_fails_beyond_percentage_and_floor"
compare '{"first_prompt_lag_ms": 126, "first_command_lag_ms": 40}'
assert_equals "1" "$RC" "+26% and +26 ms on first-prompt lag fails"
assert_contains "FAIL first_prompt_lag_ms" "$OUT" "and names the metric"

test_start "compare_floor_absorbs_jitter_on_small_numbers"
compare '{"first_prompt_lag_ms": 100, "first_command_lag_ms": 54}'
assert_equals "0" "$RC" "+35% but only +14 ms is under the 15 ms floor"
compare '{"first_prompt_lag_ms": 100, "first_command_lag_ms": 56}'
assert_equals "1" "$RC" "+16 ms and +40% fails"

test_start "compare_fails_when_a_gated_metric_is_missing"
compare '{"first_prompt_lag_ms": 90}'
assert_equals "1" "$RC" "a missing measurement is not a pass"

test_start "compare_threshold_is_configurable"
printf '{"first_prompt_lag_ms": 112, "first_command_lag_ms": 40}\n' >"$WORK/cur.json"
RC=0
ZSH_BENCH_REGRESSION_PCT=10 ZSH_BENCH_MIN_DELTA_MS=5 bash "$BENCH" compare "$WORK/cur.json" "$WORK/base.json" >/dev/null 2>&1 || RC=$?
assert_equals "1" "$RC" "+12% fails a 10% / 5 ms gate"

# ── fetch: pinned checksum ──────────────────────────────────────────────
test_start "fetch_refuses_a_tarball_that_does_not_match_the_pin"
mkdir -p "$WORK/stubs" "$WORK/evil/zsh-bench-x"
printf '#!/bin/sh\necho pwned\n' >"$WORK/evil/zsh-bench-x/zsh-bench"
tar -czf "$WORK/evil.tar.gz" -C "$WORK/evil" zsh-bench-x
cat >"$WORK/stubs/curl" <<STUB
#!/bin/sh
while [ \$# -gt 0 ]; do [ "\$1" = -o ] && { cp "$WORK/evil.tar.gz" "\$2"; exit 0; }; shift; done
exit 22
STUB
chmod +x "$WORK/stubs/curl"
RC=0
OUT="$(PATH="$WORK/stubs:$PATH" XDG_CACHE_HOME="$WORK/cache" bash "$BENCH" fetch 2>&1)" || RC=$?
assert_equals "1" "$RC" "fetch fails"
assert_contains "checksum mismatch" "$OUT" "and says why"
assert_equals "" "$(find "$WORK/cache" -name 'zsh-bench-*' -o -name 'download.*' 2>/dev/null)" \
  "nothing unverified is left in the cache"

# ── run: zsh-bench under a zsh SHELL and a deadline ────────────────────
# A fake zsh-bench stands in at the verified cache path, so fetch returns
# it without the network. FAKE_MODE=hang models the CI failure: the
# benchmarked shell never reads its input and zsh-bench waits forever.
commit="$(sed -n 's/^readonly ZSH_BENCH_COMMIT="\(.*\)"$/\1/p' "$BENCH")"
fake_dir="$WORK/runcache/dotfiles/zsh-bench/zsh-bench-$commit"
mkdir -p "$fake_dir"
cat >"$fake_dir/zsh-bench" <<'FAKE'
printf '%s\n' "$SHELL" >"$FAKE_SHELL_LOG"
[ "${FAKE_MODE:-}" = hang ] && sleep 60
printf 'first_prompt_lag_ms=( 30 10 20 )\nfirst_command_lag_ms=( 5 9 7 )\n'
FAKE
chmod +x "$fake_dir/zsh-bench"
# The timeout diagnostic starts this HOME's zsh -li in a pty.
mkdir -p "$WORK/home"
printf 'PS1="probe> "\nprint -r -- "RC-""LOADED"\n' >"$WORK/home/.zshrc"
run_bench() {
  RC=0
  OUT="$(env -u ZDOTDIR HOME="$WORK/home" SHELL=/bin/bash XDG_CACHE_HOME="$WORK/runcache" FAKE_SHELL_LOG="$WORK/shell.log" \
    bash "$BENCH" run --iters 3 2>&1)" || RC=$?
}

if command -v zsh >/dev/null 2>&1; then
  test_start "run_hands_zsh_bench_a_zsh_SHELL"
  run_bench
  assert_equals "0" "$RC" "run succeeds"
  assert_equals "$(command -v zsh)" "$(cat "$WORK/shell.log")" \
    "script(1) runs zsh-bench's zsh-syntax -c command through \$SHELL, so it must be zsh"
  assert_equals "20.0" "$(json_get first_prompt_lag_ms <<<"$OUT")" "and the medians come through"

  if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
    test_start "run_fails_loudly_when_zsh_bench_hangs"
    started=$SECONDS
    FAKE_MODE=hang ZSH_BENCH_TIMEOUT=2 run_bench
    assert_equals "1" "$RC" "a hung zsh-bench is a failure"
    assert_contains "timed out after 2s" "$OUT" "that says why"
    assert_true "[ $((SECONDS - started)) -lt 45 ]" "within the deadline (plus the probe), not the job timeout"
    if command -v script >/dev/null 2>&1; then
      assert_contains "RC-LOADED" "$OUT" "and shows what the pty shell printed"
      assert_contains "ZB-PROBE-ALIVE" "$OUT" "including whether it ran typed input"
    fi
  fi
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
