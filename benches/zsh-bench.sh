#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# benches/zsh-bench.sh — first-prompt and first-command lag of the
# interactive zsh this repo deploys, measured with romkatv/zsh-bench.
#
# `zsh -i -c exit` (perf.sh, benchmark.sh) times startup to exit; it cannot
# see work deferred to the first precmd or to the first command, which is
# where the lag a user feels lives. zsh-bench drives a real interactive
# zsh through a pty (script(1)) and reports, per iteration:
#   first_prompt_lag_ms   keypress-ready prompt after the shell starts
#   first_command_lag_ms  first command's output after it is typed
# zsh only: bash and fish stay on scripts/diagnostics/benchmark.sh.
#
# zsh-bench is MIT-licensed (Copyright (c) 2021 Roman Perepelitsa). It is
# fetched at a pinned commit, checked against a pinned SHA-256 of the
# codeload tarball, and never taken from a branch. Bump both together.
#
# Usage:
#   benches/zsh-bench.sh fetch                   # print the verified zsh-bench dir
#   benches/zsh-bench.sh run [--iters N]         # measure $HOME's zsh, JSON to stdout
#   benches/zsh-bench.sh summarize               # zsh-bench --raw output on stdin -> JSON
#   benches/zsh-bench.sh compare CURRENT BASELINE
#
# compare exits 1 when a gated metric's median exceeds the baseline by more
# than ZSH_BENCH_REGRESSION_PCT percent (default 25) AND by more than
# ZSH_BENCH_MIN_DELTA_MS (default 15) milliseconds; the absolute floor keeps
# runner jitter on small numbers from failing the gate.

set -euo pipefail

readonly ZSH_BENCH_COMMIT="28b1b1bc888159f0a2cf50f9d29381758341aba1"
readonly ZSH_BENCH_SHA256="cf6889c98513e2ced811102b2ca4ff0937466b6b8cf650967c17ab1228caf1c7"
readonly GATED_METRICS="first_prompt_lag_ms first_command_lag_ms"
readonly REPORTED_METRICS="first_prompt_lag_ms first_command_lag_ms command_lag_ms input_lag_ms exit_time_ms"

die() {
  printf 'zsh-bench: %s\n' "$1" >&2
  exit "${2:-1}"
}

_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# fetch: download the pinned tarball once into the cache, verify it, and
# print the extracted directory. A mismatch removes the download and fails.
cmd_fetch() {
  local cache dir tarball
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zsh-bench"
  dir="$cache/zsh-bench-$ZSH_BENCH_COMMIT"
  if [[ -x "$dir/zsh-bench" ]]; then
    printf '%s\n' "$dir"
    return 0
  fi
  mkdir -p "$cache"
  tarball="$(mktemp "$cache/download.XXXXXX")"
  curl -fsSL --retry 3 --max-time 120 -o "$tarball" \
    "https://codeload.github.com/romkatv/zsh-bench/tar.gz/$ZSH_BENCH_COMMIT" ||
    {
      rm -f "$tarball"
      die "download failed"
    }
  if [[ "$(_sha256 "$tarball")" != "$ZSH_BENCH_SHA256" ]]; then
    rm -f "$tarball"
    die "checksum mismatch for zsh-bench $ZSH_BENCH_COMMIT; refusing to run it"
  fi
  tar -xzf "$tarball" -C "$cache"
  rm -f "$tarball"
  [[ -x "$dir/zsh-bench" ]] || die "zsh-bench not found in the verified archive"
  printf '%s\n' "$dir"
}

# summarize: read `zsh-bench --raw` output (`name=( v1 v2 ... )` lines) and
# print {"iters": N, "<metric>": <median>, ...} for REPORTED_METRICS.
cmd_summarize() {
  awk -v metrics="$REPORTED_METRICS" '
    function median(s,   n, a, i, j, t) {
      n = split(s, a, " ")
      for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] + 0 > t + 0; j--) a[j + 1] = a[j]; a[j + 1] = t }
      return (n % 2) ? a[(n + 1) / 2] + 0 : (a[n / 2] + a[n / 2 + 1]) / 2
    }
    {
      line = $0
      eq = index(line, "=")
      if (eq == 0) next
      name = substr(line, 1, eq - 1)
      vals = substr(line, eq + 1)
      gsub(/[()]/, "", vals)
      gsub(/^ +| +$/, "", vals)
      if (vals != "") { values[name] = vals; count[name] = split(vals, tmp, " ") }
    }
    END {
      m = split(metrics, want, " ")
      printf "{\"iters\": %d", count[want[1]] + 0
      for (k = 1; k <= m; k++) if (want[k] in values) printf ", \"%s\": %.3f", want[k], median(values[want[k]])
      print "}"
    }'
}

# run [--iters N]: measure the current $HOME's interactive zsh.
cmd_run() {
  local iters=16 dir raw
  if [[ "${1:-}" == "--iters" ]]; then
    [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || die "--iters needs a positive integer" 2
    iters="$2"
  fi
  command -v zsh >/dev/null 2>&1 || die "zsh is not installed"
  dir="$(cmd_fetch)"
  raw="$(zsh "$dir/zsh-bench" --raw --iters "$iters")" || die "zsh-bench failed"
  printf '%s\n' "$raw" | cmd_summarize
}

# compare CURRENT BASELINE: gate the medians. A metric absent from the
# baseline is reported and skipped; one absent from CURRENT fails.
cmd_compare() {
  [[ -r "${1:-}" && -r "${2:-}" ]] || die "compare needs two readable JSON files" 2
  python3 - "$1" "$2" "$GATED_METRICS" \
    "${ZSH_BENCH_REGRESSION_PCT:-25}" "${ZSH_BENCH_MIN_DELTA_MS:-15}" <<'PY'
import json, sys

cur, base = (json.load(open(p)) for p in sys.argv[1:3])
pct, floor = float(sys.argv[4]), float(sys.argv[5])
failed = False
for name in sys.argv[3].split():
    if name not in cur:
        print(f"FAIL {name}: missing from the current measurement")
        failed = True
        continue
    if name not in base:
        print(f"skip {name}: not in the baseline")
        continue
    c, b = float(cur[name]), float(base[name])
    limit = max(b * (1 + pct / 100), b + floor)
    verdict = "FAIL" if c > limit else "ok"
    failed |= c > limit
    print(f"{verdict} {name}: {c:.1f} ms vs baseline {b:.1f} ms (limit {limit:.1f} ms: +{pct:g}% and +{floor:g} ms)")
sys.exit(1 if failed else 0)
PY
}

main() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    fetch) cmd_fetch ;;
    run) cmd_run "$@" ;;
    summarize) cmd_summarize ;;
    compare) cmd_compare "$@" ;;
    *) die "usage: $0 {fetch|run [--iters N]|summarize|compare CURRENT BASELINE}" 2 ;;
  esac
}

main "$@"
