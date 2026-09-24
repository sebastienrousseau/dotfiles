#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural coverage for tmux-status edge cases: colour validation and
# collision probing, other-sessions summary, short-path, platform fallbacks
# and CLI dispatch. tmux and system probes are stubs in a mktemp sandbox.
# shellcheck disable=SC1090,SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMUX_STATUS="$REPO_ROOT/defaults/dot_local/bin/executable_tmux-status"
BASH_BIN="$(command -v bash)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/home/.config" \
  XDG_CACHE_HOME="$SANDBOX/home/.cache" XDG_DATA_HOME="$SANDBOX/home/.local/share"
mkdir -p "$HOME" "$SANDBOX/bin" "$SANDBOX/empty" "$SANDBOX/runtime"

# tmux stub: sessions come from $TMUX_STATUS_TEST_SESSIONS (one per line);
# set-option calls are logged.
cat >"$SANDBOX/bin/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-sessions) printf '%s' "${TMUX_STATUS_TEST_SESSIONS:-}" ;;
  set-option) printf '%s|%s\n' "$4" "$6" >>"$TMUX_STATUS_TEST_LOG" ;;
  *) exit 2 ;;
esac
EOF
cat >"$SANDBOX/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Plan9\n'
EOF
cat >"$SANDBOX/bin/sysctl" <<'EOF'
#!/usr/bin/env bash
printf 'not-a-number\n'
EOF
cat >"$SANDBOX/bin/ps" <<'EOF'
#!/usr/bin/env bash
printf '30.0\n'
EOF
cat >"$SANDBOX/bin/memory_pressure" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$SANDBOX/bin/pmset" <<'EOF'
#!/usr/bin/env bash
printf 'Now drawing from AC Power\n'
EOF
chmod +x "$SANDBOX"/bin/*
export PATH="$SANDBOX/bin:$PATH"
export TMUX_STATUS_TEST_LOG="$SANDBOX/colours.log"

run_status() { "$BASH_BIN" "$TMUX_STATUS" "$@"; }

test_start "tmux_status_rejects_invalid_colours"
run_status apply-colours 'red' '#61b9f2' '#ef8ee9'
assert_equals "2" "$?" "invalid primary is rejected"
run_status apply-colours '#60daee' '#xyzxyz' '#ef8ee9'
assert_equals "2" "$?" "invalid secondary is rejected"
run_status apply-colours '#60daee' '#61b9f2' '#12345'
assert_equals "2" "$?" "invalid tertiary is rejected"

test_start "tmux_status_colour_probing_with_many_sessions"
sessions=$'\n'
for i in $(seq 1 14); do
  sessions+="\$$i|session-$i"$'\n'
done
: >"$TMUX_STATUS_TEST_LOG"
TMUX_STATUS_TEST_SESSIONS="$sessions" run_status apply-colours '#60daee' '#61b9f2' '#ef8ee9'
assert_equals "0" "$?" "apply-colours succeeds with more sessions than slots"
assert_equals "14" "$(wc -l <"$TMUX_STATUS_TEST_LOG" | tr -d ' ')" \
  "every non-blank session line gets a colour"
assert_equals "12" "$(cut -d '|' -f2 "$TMUX_STATUS_TEST_LOG" | sort -u | wc -l | tr -d ' ')" \
  "the first twelve sessions receive distinct colours"
: >"$TMUX_STATUS_TEST_LOG"
TMUX_STATUS_TEST_SESSIONS="" run_status apply-colours '#60daee' '#61b9f2' '#ef8ee9'
assert_equals "0" "$(wc -l <"$TMUX_STATUS_TEST_LOG" | tr -d ' ')" \
  "no sessions means no set-option calls"

test_start "tmux_status_other_sessions"
assert_equals "" "$(TMUX_STATUS_TEST_SESSIONS=$'main\n' run_status other-sessions main)" \
  "only the current session prints nothing"
assert_equals "↔ work" "$(TMUX_STATUS_TEST_SESSIONS=$'main\n\nwork\n' run_status other-sessions main)" \
  "a single other session is named without a counter"
assert_equals "↔ abcdefghijklmno… +2" \
  "$(TMUX_STATUS_TEST_SESSIONS=$'abcdefghijklmnopqrstu\nmain\nb\nc\n' run_status other-sessions main)" \
  "long names are truncated and the rest are counted"
assert_equals "↔ exactly16chars!!" \
  "$(TMUX_STATUS_TEST_SESSIONS=$'exactly16chars!!\n' run_status other-sessions main)" \
  "a sixteen-character name is not truncated"

test_start "tmux_status_short_path_edges"
assert_equals "" "$(run_status short-path)" "empty path prints nothing"
assert_equals "project" "$(run_status short-path /project)" "top-level dir prints the leaf"
assert_equals "Code/project" "$(run_status short-path /Users/Code/project/)" \
  "trailing slash is ignored"
assert_equals "same" "$(run_status short-path same/same)" \
  "parent equal to leaf prints the leaf once"

test_start "tmux_status_system_unknown_platform"
assert_equals "" "$(TMUX_STATUS_PLATFORM='' run_status system)" \
  "uname fallback with an unknown platform prints nothing"

test_start "tmux_status_darwin_fallbacks"
darwin_out="$(TMUX_STATUS_PLATFORM=Darwin run_status system)"
assert_equals "0" "$(grep -c "·" <<<"$darwin_out")" "missing memory and battery add no separators"
assert_contains "30%" "$darwin_out" \
  "invalid core count defaults to 1; missing memory and battery are omitted"

test_start "tmux_status_linux_state_and_missing_sources"
mkdir -p "$SANDBOX/proc" "$SANDBOX/sys/class/power_supply/BAT0"
printf 'cpu 100 0 50 850 0 0 0 0 0 0\n' >"$SANDBOX/proc/stat"
printf '500 450\n' >"$SANDBOX/runtime/dotfiles-tmux-cpu-${UID:-0}.state"
linux() {
  TMUX_STATUS_PLATFORM=Linux TMUX_STATUS_PROC_ROOT="$SANDBOX/proc" \
    TMUX_STATUS_SYS_ROOT="$SANDBOX/sys" XDG_RUNTIME_DIR="$SANDBOX/runtime" \
    run_status system
}
assert_contains " 20%" "$(linux)" "CPU delta from the previous sample is used"
assert_equals "1000 850" "$(cat "$SANDBOX/runtime/dotfiles-tmux-cpu-${UID:-0}.state")" \
  "the sample is persisted for the next call"
assert_equals "" "$(linux)" "an unchanged sample yields no CPU figure"
rm -f "$SANDBOX/proc/stat"
assert_equals "" "$(linux)" "no procfs and no battery capacity prints nothing"

test_start "tmux_status_windows_without_powershell"
assert_equals "" "$(TMUX_STATUS_PLATFORM=MSYS_NT PATH="$SANDBOX/empty" run_status system)" \
  "missing powershell.exe prints nothing"

test_start "tmux_status_cli_dispatch"
assert_contains "Usage: tmux-status" "$(run_status --help)" "--help prints usage"
assert_contains "short-path" "$(run_status -h)" "-h prints usage"
err="$(run_status bogus 2>&1)"
rc=$?
assert_equals "2" "$rc" "unknown command exits 2"
assert_contains "Usage: tmux-status" "$err" "unknown command prints usage to stderr"
run_status 2>/dev/null
assert_equals "2" "$?" "no command exits 2"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
