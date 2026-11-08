#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Wallpaper-aware tmux status helper validation.
# shellcheck disable=SC1090,SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMUX_STATUS="$REPO_ROOT/defaults/dot_local/bin/executable_tmux-status"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin"

cat >"$SANDBOX/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  list-sessions)
    printf '%s\n' \
      '$1|DOT' \
      '$2|STD' \
      '$3|ssg-themes' \
      '$4|research'
    ;;
  set-option)
    printf '%s|%s\n' "$4" "$6" >>"$TMUX_STATUS_TEST_LOG"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$SANDBOX/bin/tmux"

cat >"$SANDBOX/bin/sysctl" <<'EOF'
#!/usr/bin/env bash
printf '4\n'
EOF
cat >"$SANDBOX/bin/ps" <<'EOF'
#!/usr/bin/env bash
printf '40.0\n20.0\n'
EOF
cat >"$SANDBOX/bin/memory_pressure" <<'EOF'
#!/usr/bin/env bash
printf 'System-wide memory free percentage: 42%%\n'
EOF
cat >"$SANDBOX/bin/pmset" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' ' -InternalBattery-0 80%; charging; present: true'
EOF
cat >"$SANDBOX/bin/powershell.exe" <<'EOF'
#!/usr/bin/env bash
printf '25|61|77\r\n'
EOF
chmod +x "$SANDBOX/bin/sysctl" "$SANDBOX/bin/ps" \
  "$SANDBOX/bin/memory_pressure" "$SANDBOX/bin/pmset" \
  "$SANDBOX/bin/powershell.exe"

test_start "tmux_status_exists"
assert_file_exists "$TMUX_STATUS" "tmux status helper must exist"

test_start "tmux_status_assigns_unique_apple_session_colours"
TMUX_STATUS_TEST_LOG="$SANDBOX/colours.log" \
  PATH="$SANDBOX/bin:$PATH" \
  bash "$TMUX_STATUS" apply-colours '#ff6165/#000000' '#ff9230/#000000' '#ffd600/#000000' '#30d158/#000000' '#00dac3/#000000' '#00d2e0/#000000' '#3cd3fe/#000000' '#5cb8ff/#000000' '#a7aaff/#000000' '#ea8dff/#000000' '#ff8ac4/#000000' '#dba679/#000000'
assigned="$(wc -l <"$SANDBOX/colours.log" | tr -d ' ')"
unique="$(cut -d '|' -f2 "$SANDBOX/colours.log" | sort -u | wc -l | tr -d ' ')"
assert_equals "4" "$assigned" "every active session receives a color"
assert_equals "4" "$unique" "active sessions avoid color collisions"

test_start "tmux_status_shortens_context"
assert_equals "Public/project" \
  "$(bash "$TMUX_STATUS" short-path /Users/seb/Code/Public/project)" \
  "working directory context contains only two path components"

test_start "tmux_status_monitors_macos"
darwin_status="$(TMUX_STATUS_PLATFORM=Darwin PATH="$SANDBOX/bin:$PATH" bash "$TMUX_STATUS" system)"
assert_contains " 15%" "$darwin_status" "macOS CPU usage is normalized by core count"
assert_contains " 58%" "$darwin_status" "macOS memory pressure becomes used percentage"
assert_contains " 80%" "$darwin_status" "macOS battery is reported when present"

test_start "tmux_status_monitors_linux_and_wsl"
mkdir -p "$SANDBOX/proc" "$SANDBOX/sys/class/power_supply/BAT0" "$SANDBOX/runtime"
cat >"$SANDBOX/proc/stat" <<'EOF'
cpu 100 0 50 850 0 0 0 0 0 0
EOF
cat >"$SANDBOX/proc/meminfo" <<'EOF'
MemTotal:        1000 kB
MemAvailable:     400 kB
EOF
printf '90\n' >"$SANDBOX/sys/class/power_supply/BAT0/capacity"
linux_status="$(
  TMUX_STATUS_PLATFORM=Linux \
    TMUX_STATUS_PROC_ROOT="$SANDBOX/proc" \
    TMUX_STATUS_SYS_ROOT="$SANDBOX/sys" \
    XDG_RUNTIME_DIR="$SANDBOX/runtime" \
    bash "$TMUX_STATUS" system
)"
assert_contains " 15%" "$linux_status" "Linux and WSL CPU usage comes from procfs"
assert_contains " 60%" "$linux_status" "Linux and WSL memory usage comes from procfs"
assert_contains " 90%" "$linux_status" "Linux battery is reported when present"

test_start "tmux_status_monitors_windows"
windows_status="$(TMUX_STATUS_PLATFORM=MINGW64_NT PATH="$SANDBOX/bin:$PATH" bash "$TMUX_STATUS" system)"
assert_contains " 25%" "$windows_status" "Windows CPU usage comes from PowerShell CIM"
assert_contains " 61%" "$windows_status" "Windows memory usage comes from PowerShell CIM"
assert_contains " 77%" "$windows_status" "Windows battery usage comes from PowerShell CIM"

# tmux-status agents counts the agent sessions dot ai status lists, from
# the state files the hook writes: gone ones and those silent for a day
# are left out, and a blocked one is named in text, not colour alone.
test_start "tmux_status_counts_live_agents"
agents_dir="$SANDBOX/state/dot/cli/agents"
mkdir -p "$agents_dir/claude" "$agents_dir/codex"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
agent_record() { # agent_record FILE STATE TIME
  printf '{"schema":"cli/agent-event.v1","time":"%s","agent":"a","session":"s","state":"%s","event":"e","cwd":"/"}\n' "$3" "$2" >"$1"
}
agents() { XDG_STATE_HOME="$SANDBOX/state" bash "$TMUX_STATUS" agents; }
assert_equals "" "$(agents)" "no state files: the segment is empty"
agent_record "$agents_dir/claude/one.json" running "$now"
agent_record "$agents_dir/claude/two.json" gone "$now"
agent_record "$agents_dir/codex/old.json" blocked 2020-01-01T00:00:00Z
assert_equals "1 agent" "$(agents)" "gone and day-old sessions are left out"
agent_record "$agents_dir/codex/three.json" blocked "$now"
agent_record "$agents_dir/codex/four.json" idle "$now"
assert_equals "3 agents · 1 blocked" "$(agents)" "a blocked session is named"
printf 'not json\n' >"$agents_dir/codex/bad.json"
assert_equals "3 agents · 1 blocked" "$(agents)" "an unreadable record is skipped"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
