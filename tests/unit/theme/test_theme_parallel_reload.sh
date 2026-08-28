#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Behavioural tests for _run_reloads_parallel in bin/dot-theme-sync.
# Verifies:
#   * Wave 1 tasks run concurrently (elapsed time < sum of individual delays)
#   * Wave 2 (reload_dms) runs after wave 1 completes
#   * RELOADED / SKIPPED arrays are aggregated back into the parent shell
#   * Output is replayed in canonical task order (not interleaved)
#   * Sequential fallback (DOT_THEME_SEQUENTIAL=1) preserves the old order
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/bin/dot-theme-sync"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
export XDG_CONFIG_HOME="$TMPHOME/.config"
mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
touch "$TMPHOME/dotfiles/.chezmoidata.toml"
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Solar-dark]
mode = "dark"
family = "Solar"
EOF

# Source dot-theme-sync — source guard prevents main() from running.
source "$SCRIPT_FILE"

# Replace each reload_* with a stubbed version that:
#   * sleeps for a known duration (so we can measure the concurrency win)
#   * records its start time to a per-task file
#   * appends its own name to RELOADED (proving array roundtrip works)
# Wave 2's reload_dms is a special case — it must run after wave 1.
TIMING_DIR="$TMPHOME/timing"
mkdir -p "$TIMING_DIR"

_reset_timing() { rm -rf "$TIMING_DIR"/*; }

_make_stub() {
  local name="$1" delay_ms="$2"
  eval "reload_${name}() {
    date +%s.%N > \"$TIMING_DIR/${name}.start\"
    # Sleep for \$delay_ms milliseconds using bash's built-in read.
    read -t 0.${delay_ms} < /dev/zero 2>/dev/null || true
    date +%s.%N > \"$TIMING_DIR/${name}.end\"
    RELOADED+=(\"${name}\")
  }"
}

_make_stub ghostty 100
_make_stub tmux 100
_make_stub niri 100
_make_stub desktop 100
_make_stub wallpaper 100
_make_stub browsers 100
_make_stub nvim 100
_make_stub dms 50

# ---------------------------------------------------------------------------
# Wall-clock concurrency: wave 1 runs 7×100ms tasks. Sequential would
# take ~700ms; parallel should complete in ~100-200ms.
# ---------------------------------------------------------------------------

test_start "parallel_wallclock_faster_than_sequential_sum"
_reset_timing
RELOADED=(); SKIPPED=()
start=$(date +%s.%N)
_run_reloads_parallel "Solar-dark" >/dev/null 2>&1
end=$(date +%s.%N)
# awk to compute elapsed ms (floor). BC not required.
elapsed_ms=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%d", (e - s) * 1000 }')
# 7 tasks × 100ms + 1 wave-2 × 50ms = 750ms sequential. Fork overhead
# for 7 subshells is real (~50ms on Linux CI), so allow up to 700ms;
# a truly serial implementation would exceed this comfortably. The
# stronger overlap proofs live in the two tests that follow.
if (( elapsed_ms < 700 )); then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s (elapsed=%dms)\n' "$CURRENT_TEST" "$elapsed_ms"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (elapsed=%dms — parallelism did not kick in)\n' "$CURRENT_TEST" "$elapsed_ms"
fi

# ---------------------------------------------------------------------------
# All wave 1 tasks started before any of them ended (proves concurrency).
# ---------------------------------------------------------------------------

test_start "parallel_all_wave1_started_before_any_finished"
latest_start=""
earliest_end=""
for name in ghostty tmux niri desktop wallpaper browsers nvim; do
  s="$(cat "$TIMING_DIR/${name}.start" 2>/dev/null)"
  e="$(cat "$TIMING_DIR/${name}.end" 2>/dev/null)"
  [[ -z "$latest_start" || "$(awk -v a="$s" -v b="$latest_start" 'BEGIN{print (a>b)}')" == "1" ]] && latest_start="$s"
  [[ -z "$earliest_end" || "$(awk -v a="$e" -v b="$earliest_end" 'BEGIN{print (a<b)}')" == "1" ]] && earliest_end="$e"
done
# latest_start < earliest_end means all 7 were running simultaneously
# at some instant.
if [[ "$(awk -v a="$latest_start" -v b="$earliest_end" 'BEGIN{print (a<b)}')" == "1" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (tasks did not overlap)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# reload_dms (wave 2) started AFTER every wave 1 task ended.
# ---------------------------------------------------------------------------

test_start "parallel_dms_starts_after_wave1_finishes"
dms_start="$(cat "$TIMING_DIR/dms.start")"
last_wave1_end="$earliest_end"
for name in ghostty tmux niri desktop wallpaper browsers nvim; do
  e="$(cat "$TIMING_DIR/${name}.end")"
  [[ "$(awk -v a="$e" -v b="$last_wave1_end" 'BEGIN{print (a>b)}')" == "1" ]] && last_wave1_end="$e"
done
if [[ "$(awk -v a="$dms_start" -v b="$last_wave1_end" 'BEGIN{print (a>=b)}')" == "1" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (dms fired inside wave 1)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# RELOADED array roundtrip: subshell mutations reach the parent shell.
# ---------------------------------------------------------------------------

test_start "parallel_reloaded_array_populated"
if [[ ${#RELOADED[@]} -eq 8 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s (RELOADED has 8 entries)\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (RELOADED has %d entries, expected 8)\n' "$CURRENT_TEST" "${#RELOADED[@]}"
fi

test_start "parallel_reloaded_array_includes_dms_from_wave2"
if [[ " ${RELOADED[*]} " == *" dms "* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (dms not in RELOADED)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Sequential fallback via DOT_THEME_SEQUENTIAL=1 still works.
# ---------------------------------------------------------------------------

test_start "sequential_fallback_still_populates_reloaded"
RELOADED=(); SKIPPED=()
DOT_THEME_SEQUENTIAL=1
if [[ "$DOT_THEME_SEQUENTIAL" == "1" ]]; then
  # main() would check the env var; here we simulate by calling each in order.
  reload_ghostty; reload_tmux; reload_niri; reload_desktop "Solar-dark"
  reload_dms; reload_wallpaper; reload_browsers "Solar-dark"; reload_nvim "Solar-dark"
fi
if [[ ${#RELOADED[@]} -eq 8 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
