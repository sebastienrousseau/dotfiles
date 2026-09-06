#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Conversion tests for the `epoch` CLI.
#
# epoch branches on which `date` it finds: GNU date parses with -d,
# BSD/macOS date needs -j -f and -r, and only GNU date understands
# %3N for milliseconds. Each case below supplies a `date` shim that
# behaves like exactly one of those, so both platform arms and the
# gdate / python3 / seconds-times-1000 millisecond fallbacks all run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

EPOCH_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_epoch"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
mkdir -p "$TMP/ep-home"

E_BIN=""
_ep_scenario() {
  E_BIN="$TMP/ep-$1"
  mkdir -p "$E_BIN"
  local tool p
  for tool in grep printf env cat sed; do
    p="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$E_BIN/$tool"
  done
  ln -sf "$BASH" "$E_BIN/bash"
}

_ep_shim() {
  cat >"$E_BIN/$1"
  chmod +x "$E_BIN/$1"
}

E_OUT=""
E_RC=0
_run_epoch() {
  E_RC=0
  E_OUT="$(
    env BASH_XTRACEFD=21 PATH="$E_BIN" HOME="$TMP/ep-home" "$BASH" "$EPOCH_FILE" "$@" </dev/null 2>&1
  )" || E_RC=$?
}

_ep_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$E_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $E_RC"
  for needle in "$@"; do
    [[ "$E_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$E_OUT" | sed 's/^/      /'
  fi
}

# GNU date: -d parses, -r is not a timestamp flag, %s%3N works.
_gnu_date() {
  _ep_shim date <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -d)
    case "$2" in
      "@"*) echo "GNU-date-for-epoch ${2#@}" ;;
      *) echo "1705276800" ;;
    esac
    exit 0
    ;;
  +%s%3N)
    echo "1705276800123"
    exit 0
    ;;
  +%s)
    echo "1705276800"
    exit 0
    ;;
esac
exit 1
EOF
}

# BSD date: no -d, needs -j -f to parse and -r to format a timestamp,
# and emits a literal N for %3N.
_bsd_date() {
  _ep_shim date <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -d) exit 1 ;;
  -j)
    # -j -f "%Y-%m-%d" "<str>" +%s
    echo "1705276800"
    exit 0
    ;;
  -r)
    echo "BSD-date-for-epoch $2"
    exit 0
    ;;
  +%s%3N)
    echo "1705276800N"
    exit 0
    ;;
  +%s)
    echo "1705276800"
    exit 0
    ;;
esac
exit 1
EOF
}

# =======================================================================
# 1. Help and unknown options.
# =======================================================================
_ep_scenario help
_gnu_date
_run_epoch --help
_ep_expect "help_lists_options" 0 \
  "convert to/from unix time" "Usage: epoch [options] [value]" \
  "-r, --reverse   Convert date string to epoch" "-m, --millis    Use milliseconds"

_run_epoch -h
_ep_expect "short_help_flag" 0 "Usage: epoch [options] [value]"

_run_epoch --nope
_ep_expect "unknown_option_exits_2" 2 "Unknown option: --nope"

# =======================================================================
# 2. Current time, seconds and milliseconds, across the fallback chain.
# =======================================================================
_run_epoch
_ep_expect "no_argument_prints_current_epoch_seconds" 0 "1705276800"

_run_epoch -m
_ep_expect "millis_via_gnu_date_3N" 0 "1705276800123"

_run_epoch --millis
_ep_expect "millis_long_flag" 0 "1705276800123"

# BSD date: %3N is unusable, but gdate is installed.
_ep_scenario millis_gdate
_bsd_date
_ep_shim gdate <<'EOF'
#!/usr/bin/env bash
echo "1705276800456"
EOF
_run_epoch -m
_ep_expect "millis_falls_back_to_gdate" 0 "1705276800456"

# No gdate, but python3 is available.
_ep_scenario millis_python
_bsd_date
_ep_shim python3 <<'EOF'
#!/usr/bin/env bash
echo "1705276800789"
EOF
_run_epoch -m
_ep_expect "millis_falls_back_to_python3" 0 "1705276800789"

# Neither: degrade to seconds * 1000.
_ep_scenario millis_bare
_bsd_date
_run_epoch -m
_ep_expect "millis_degrades_to_seconds_times_1000" 0 "1705276800000"

# =======================================================================
# 3. Epoch -> date, on both platforms, with the millisecond trim.
# =======================================================================
_ep_scenario to_date_gnu
_gnu_date
_run_epoch 1705276800
_ep_expect "gnu_date_formats_a_timestamp" 0 "GNU-date-for-epoch 1705276800"

_run_epoch 1705276800123
_ep_expect "millisecond_timestamps_are_divided_by_1000" 0 "GNU-date-for-epoch 1705276800"

_ep_scenario to_date_bsd
_bsd_date
_run_epoch 1705276800
_ep_expect "bsd_date_formats_a_timestamp" 0 "BSD-date-for-epoch 1705276800"

_run_epoch not-a-number
_ep_expect "non_numeric_epoch_exits_2" 2 "Invalid epoch value: not-a-number"

# =======================================================================
# 4. Date -> epoch (--reverse), on both platforms.
# =======================================================================
_ep_scenario reverse_gnu
_gnu_date
_run_epoch --reverse "2024-01-15"
_ep_expect "reverse_parses_with_gnu_date" 0 "1705276800"

_run_epoch -r "2024-01-15"
_ep_expect "reverse_short_flag" 0 "1705276800"

_run_epoch -r
_ep_expect "reverse_without_a_value_exits_1" 1

_ep_scenario reverse_bsd
_bsd_date
_run_epoch -r "2024-01-15"
_ep_expect "reverse_parses_with_bsd_date_j_f" 0 "1705276800"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
