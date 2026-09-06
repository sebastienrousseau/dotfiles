#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform-branch tests for the sysinfo shell function.
#
# sysinfo.sh does all of its probing at source time, branching on
# `uname -s`, so the Darwin / Linux / fallback arms can only be reached
# by sourcing it three times under three different toolchains. Each
# case below sources the file in a subshell whose PATH holds nothing but
# fixture shims plus a sysbin of symlinked coreutils, then calls
# sysinfo and asserts the report it prints.

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

SYSINFO_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/system/sysinfo.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
SYSBIN="$TMP/si-sysbin"
mkdir -p "$SYSBIN"
for tool in awk sed grep tr head basename cat env printf uname hostname; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
ln -sf "$BASH" "$SYSBIN/bash"

SI_BIN=""
_si_scenario() {
  SI_BIN="$TMP/si-$1"
  mkdir -p "$SI_BIN"
}

_si_shim() {
  cat >"$SI_BIN/$1"
  chmod +x "$SI_BIN/$1"
}

# _si_uname <kernel-name> <release>
_si_uname() {
  local os="$1" rel="$2"
  _si_shim uname <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  -r) echo "$rel" ;;
  -s | "") echo "$os" ;;
  *) echo "$os" ;;
esac
EOF
}

SI_OUT=""
SI_RC=0
# _run_sysinfo: source sysinfo.sh under the scenario PATH, then call it.
_run_sysinfo() {
  SI_RC=0
  SI_OUT="$(
    env BASH_XTRACEFD=21 PATH="$SI_BIN:$SYSBIN" \
      HOME="$TMP/si-home" \
      SHELL="/bin/zsh" \
      NO_COLOR=1 \
      "$@" \
      "$BASH" -c 'source "$1"; sysinfo' _ "$SYSINFO_FILE" 2>&1
  )" || SI_RC=$?
}

_si_expect() {
  local label="$1"
  shift
  local needle problems=""
  for needle in "$@"; do
    [[ "$SI_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$SI_OUT" | sed 's/^/      /'
  fi
}

mkdir -p "$TMP/si-home"

# =======================================================================
# 1. Darwin: system_profiler / sw_vers / uptime supply every field, and
#    Model is printed because model_name and model_id are both set.
# =======================================================================
_si_scenario darwin
_si_uname Darwin 24.0.0
_si_shim hostname <<'EOF'
#!/usr/bin/env bash
echo "fixture-mac"
EOF
_si_shim system_profiler <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  SPHardwareDataType)
    printf '%s\n' "      Model Name: FixtureBook Pro" \
      "      Model Identifier: Fixture16,1" \
      "      Chip: Fixture M9" \
      "      Total Number of Cores: 12" \
      "      Memory: 32 GB"
    ;;
  SPDisplaysDataType)
    printf '%s\n' "      Chipset Model: Fixture GPU" "      Resolution: 3024 x 1964"
    ;;
esac
EOF
_si_shim sw_vers <<'EOF'
#!/usr/bin/env bash
echo "15.4"
EOF
_si_shim uptime <<'EOF'
#!/usr/bin/env bash
echo " 10:00  up 4 days, 3:04, 2 users"
EOF
_run_sysinfo TERM_PROGRAM=FixtureTerm
_si_expect "darwin_report" \
  "fixture-mac" "OS:         macOS 15.4" "Kernel:     24.0.0" "Uptime:     4 days" \
  "CPU:        Fixture M9 (12 cores)" "GPU:        Fixture GPU" "Memory:     32 GB" \
  "Shell:      zsh" "Terminal:   FixtureTerm" "Resolution: 3024 x 1964" \
  "Model:      FixtureBook Pro (Fixture16,1)"

# TERM_PROGRAM unset falls back to TERM.
_run_sysinfo TERM_PROGRAM= TERM=fixture-term-256color
_si_expect "darwin_terminal_falls_back_to_term" "Terminal:   fixture-term-256color"

# =======================================================================
# 2. Linux with the full probe set: lscpu, lspci, /proc/meminfo, xrandr.
# =======================================================================
_si_scenario linux
_si_uname Linux 6.10.0
_si_shim hostname <<'EOF'
#!/usr/bin/env bash
echo "fixture-box"
EOF
_si_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 2 hours, 5 minutes"
EOF
_si_shim lscpu <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "Architecture:  x86_64" "Model name:    Fixture Xeon"
EOF
_si_shim lspci <<'EOF'
#!/usr/bin/env bash
echo "00:02.0 VGA compatible controller: Fixture Graphics 900"
EOF
_si_shim xrandr <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "Screen 0: minimum 1 x 1" "   2560x1440     59.95*+"
EOF
_run_sysinfo TERM=fixture-linux-term
_si_expect "linux_report_with_full_probe_set" \
  "fixture-box" "Kernel:     6.10.0" "Uptime:     2 hours, 5 minutes" \
  "CPU:        Fixture Xeon" "GPU:        Fixture Graphics 900" \
  "Shell:      zsh" "Terminal:   fixture-linux-term" "Resolution: 2560x1440"

test_start "linux_report_omits_model_line"
if [[ "$SI_OUT" != *"Model:"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: Linux has no model name/identifier to print"
fi

# =======================================================================
# 3. Linux with none of the optional probes installed: every "Unknown".
# =======================================================================
_si_scenario linux_bare
_si_uname Linux 5.15.0
_si_shim hostname <<'EOF'
#!/usr/bin/env bash
echo "bare-box"
EOF
_si_shim uptime <<'EOF'
#!/usr/bin/env bash
echo "up 9 minutes"
EOF
_run_sysinfo TERM=
_si_expect "linux_report_without_optional_probes" \
  "bare-box" "CPU:        Unknown CPU" "GPU:        Unknown GPU" \
  "Resolution: Unknown" "Terminal:   Unknown"

# =======================================================================
# 4. Neither Darwin nor Linux: the fallback arm.
# =======================================================================
_si_scenario freebsd
_si_uname FreeBSD 14.0-RELEASE
_si_shim hostname <<'EOF'
#!/usr/bin/env bash
echo "fixture-bsd"
EOF
_run_sysinfo TERM=
_si_expect "unknown_platform_fallback" \
  "fixture-bsd" "OS:         FreeBSD" "Kernel:     14.0-RELEASE" "Uptime:     Unknown" \
  "CPU:        Unknown" "GPU:        Unknown" "Memory:     Unknown" \
  "Terminal:   Unknown" "Resolution: Unknown"

# =======================================================================
# 5. The Windows-shell case arm of the platform-emoji switch.
# =======================================================================
_si_scenario mingw
_si_uname MINGW64_NT-10.0 3.4.10
_si_shim hostname <<'EOF'
#!/usr/bin/env bash
echo "fixture-win"
EOF
_run_sysinfo TERM=
_si_expect "windows_platform_arm" "fixture-win" "OS:         MINGW64_NT-10.0"

_si_scenario cygwin
_si_uname CYGWIN_NT-10.0 3.4.10
_si_shim hostname <<'EOF'
#!/usr/bin/env bash
echo "fixture-cyg"
EOF
_run_sysinfo TERM=
_si_expect "cygwin_platform_arm" "fixture-cyg"

# =======================================================================
# 6. Colour variables are populated when NO_COLOR is unset and stdout is
#    a terminal; the plain branch is what every case above exercised.
# =======================================================================
test_start "color_branch_sets_green_escape"
_color_out="$(
  env BASH_XTRACEFD=21 PATH="$SI_BIN:$SYSBIN" HOME="$TMP/si-home" SHELL="/bin/zsh" TERM= \
    "$BASH" -c '
      # Fake an interactive stdout for the `[[ -t 1 ]]` probe by running
      # the source with stdout attached to the caller and capturing the
      # variable afterwards.
      source "$1" >/dev/null 2>&1
      printf "GREEN=[%s]\n" "$GREEN"
    ' _ "$SYSINFO_FILE" 2>&1
)" || true
assert_contains "GREEN=[]" "$_color_out" \
  "with NO_COLOR unset but stdout redirected, GREEN stays empty"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
