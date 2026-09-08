#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behaviour tests for four single-purpose bin utilities: monitor, up, pw
# and start-niri.
#
# Each of them ends by handing control to a program that would take over
# the terminal (tmux, the login shell, niri) or by writing to the system
# clipboard. Every case runs with PATH pointing at recording shims, so
# the final hand-off is captured as argv in a log file rather than
# executed.

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

BIN_DIR="$REPO_ROOT/defaults/dot_local/bin"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
CALLS="$TMP/util-calls.log"
mkdir -p "$TMP/util-home"

# `env -i` gives each run a hermetic environment, but it would also drop
# BASH_ENV, which is how the repo's coverage runner turns on xtrace in
# child shells. Carry it through explicitly when it is set.
COV_ENV=(BASH_XTRACEFD=21)
[[ -n "${BASH_ENV:-}" ]] && COV_ENV+=("BASH_ENV=$BASH_ENV")

U_BIN=""
_u_scenario() {
  U_BIN="$TMP/util-$1"
  shift
  mkdir -p "$U_BIN"
  local tool p
  for tool in cat env printf sed grep head tr "$@"; do
    p="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$U_BIN/$tool"
  done
  ln -sf "$BASH" "$U_BIN/bash"
}

# _u_record <name>: a shim that appends its argv to the call log.
_u_record() {
  rm -f "$U_BIN/$1"
  cat >"$U_BIN/$1" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$1" "\$*" >>"$CALLS"
cat >/dev/null 2>&1 || true
exit 0
EOF
  chmod +x "$U_BIN/$1"
}

_u_shim() {
  rm -f "$U_BIN/$1"
  cat >"$U_BIN/$1"
  chmod +x "$U_BIN/$1"
}

U_OUT=""
U_RC=0
# _run_util <script-basename> [args...]
_run_util() {
  local name="$1"
  shift
  U_RC=0
  : >"$CALLS"
  U_OUT="$(
    cd "$TMP/util-home" &&
      env -i "${COV_ENV[@]+"${COV_ENV[@]}"}" PATH="$U_BIN" HOME="$TMP/util-home" SHELL="$U_BIN/loginshell" \
        TMUX="${U_TMUX:-}" \
        "$BASH" "$BIN_DIR/$name" "$@" </dev/null 2>&1
  )" || U_RC=$?
}

_u_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$U_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $U_RC"
  for needle in "$@"; do
    [[ "$U_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$U_OUT" | sed 's/^/      /'
  fi
}

_u_ran() {
  local label="$1" expected="$2"
  test_start "$label"
  if grep -qF -- "$expected" "$CALLS" 2>/dev/null; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected call '$expected'"
    sed 's/^/      /' "$CALLS" 2>/dev/null || printf '      (no calls recorded)\n'
  fi
}

# =======================================================================
# monitor — tmux/btop preflight and the per-platform GPU tool choice.
# =======================================================================
_u_scenario mon_notmux uname
_u_record btop
_run_util executable_monitor
_u_expect "monitor_without_tmux_falls_back_to_btop" 0 "monitor requires tmux"
_u_ran "monitor_fallback_execs_btop" "btop "

_u_scenario mon_nobtop uname
_u_record tmux
_run_util executable_monitor
_u_expect "monitor_without_btop_exits_1" 1 "monitor requires btop"

_mon_scenario() {
  _u_scenario "mon_$1" uname
  shift
  _u_record tmux
  _u_record btop
  local t
  for t in "$@"; do _u_record "$t"; done
}

_mon_uname() {
  _u_shim uname <<EOF
#!/usr/bin/env bash
echo "$1"
EOF
}

_mon_scenario darwin powermetrics
_mon_uname Darwin
_run_util executable_monitor
_u_ran "monitor_on_macos_uses_powermetrics" "tmux new-session -s monitor btop ; split-window sudo powermetrics --samplers gpu_power -i 2000"

_mon_scenario darwin_bare
_mon_uname Darwin
_run_util executable_monitor
_u_ran "monitor_on_macos_without_powermetrics_explains" "split-window bash -c printf 'macOS GPU metrics require powermetrics"

_mon_scenario linux_nvtop nvtop amdgpu_top nvidia-smi
_mon_uname Linux
_run_util executable_monitor
_u_ran "monitor_on_linux_prefers_nvtop" "split-window nvtop"

_mon_scenario linux_amd amdgpu_top nvidia-smi
_mon_uname Linux
_run_util executable_monitor
_u_ran "monitor_on_linux_falls_back_to_amdgpu_top" "split-window amdgpu_top --dark"

_mon_scenario linux_nvidia nvidia-smi
_mon_uname Linux
_run_util executable_monitor
_u_ran "monitor_on_linux_falls_back_to_nvidia_smi" "split-window nvidia-smi"

_mon_scenario linux_intel intel_gpu_top
_mon_uname Linux
_run_util executable_monitor
_u_ran "monitor_on_linux_falls_back_to_intel_gpu_top" "split-window sudo intel_gpu_top"

_mon_scenario linux_bare
_mon_uname Linux
_run_util executable_monitor
_u_ran "monitor_on_linux_without_gpu_tools_explains" "split-window bash -c printf 'No GPU monitoring tools found."

_mon_scenario freebsd
_mon_uname FreeBSD
_run_util executable_monitor
_u_ran "monitor_on_other_platforms_explains" "split-window bash -c printf 'GPU monitoring not supported on this platform."

# Inside an existing tmux session, monitor opens a window instead.
_mon_scenario inside_tmux nvtop
_mon_uname Linux
U_TMUX="/tmp/tmux-1000/default,1,0"
_run_util executable_monitor
U_TMUX=""
_u_ran "monitor_inside_tmux_opens_a_window" "tmux new-window -n monitor btop"

# =======================================================================
# up — level to relative-path mapping.
# =======================================================================
_u_scenario up
_u_shim loginshell <<EOF
#!/usr/bin/env bash
printf 'loginshell cwd=%s\n' "\$(pwd)"
exit 0
EOF
mkdir -p "$TMP/util-home/a/b/c/d/e/f/g"

_up_at() {
  local label="$1" start="$2" arg="$3" want_suffix="$4"
  U_RC=0
  U_OUT="$(
    cd "$start" &&
      env -i "${COV_ENV[@]+"${COV_ENV[@]}"}" PATH="$U_BIN" HOME="$TMP/util-home" SHELL="$U_BIN/loginshell" \
        "$BASH" "$BIN_DIR/executable_up" $arg </dev/null 2>&1
  )" || U_RC=$?
  local want_real
  want_real="$(cd "$want_suffix" && pwd -P)"
  test_start "$label"
  if [[ "$U_OUT" == *"loginshell cwd=$want_real" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: want cwd $want_real"
    printf '%s\n' "$U_OUT" | sed 's/^/      /'
  fi
}

DEEP="$TMP/util-home/a/b/c/d/e/f/g"
_up_at "up_default_is_one_level" "$DEEP" "" "$TMP/util-home/a/b/c/d/e/f"
_up_at "up_1_is_one_level" "$DEEP" "1" "$TMP/util-home/a/b/c/d/e/f"
_up_at "up_2_is_two_levels" "$DEEP" "2" "$TMP/util-home/a/b/c/d/e"
_up_at "up_3_is_three_levels" "$DEEP" "3" "$TMP/util-home/a/b/c/d"
_up_at "up_4_climbs_five_levels" "$DEEP" "4" "$TMP/util-home/a/b"
_up_at "up_5_climbs_six_levels" "$DEEP" "5" "$TMP/util-home/a"
_up_at "up_unknown_level_is_one_level" "$DEEP" "nonsense" "$TMP/util-home/a/b/c/d/e/f"

# =======================================================================
# pw — length validation and generator preference.
# =======================================================================
_u_scenario pw_pwgen
_u_record cb
_u_shim pwgen <<'EOF'
#!/usr/bin/env bash
echo "pwgen-generated-secret"
EOF
_run_util executable_pw
_u_expect "pw_default_length_is_48" 0 "Password (48 chars) copied to clipboard."
_u_ran "pw_prefers_pwgen" "cb "

_run_util executable_pw 64
_u_expect "pw_accepts_a_custom_length" 0 "Password (64 chars) copied to clipboard."

for bad in 0 1025 abc -5 99999; do
  _run_util executable_pw "$bad"
  _u_expect "pw_rejects_length_${bad}" 1 "Usage: pw [length] (1-1024, default 48)"
done

_u_scenario pw_openssl
_u_record cb
_u_shim openssl <<'EOF'
#!/usr/bin/env bash
echo "openssl-generated-secret-material-long-enough-for-any-length"
EOF
_run_util executable_pw 12
_u_expect "pw_falls_back_to_openssl" 0 "Password (12 chars) copied to clipboard."
_u_ran "pw_openssl_pipes_into_cb" "cb "

_u_scenario pw_bare
_u_record cb
_run_util executable_pw
_u_expect "pw_without_a_generator_exits_1" 1 "Requires pwgen or openssl"

# =======================================================================
# start-niri — flag handling and the niri preflight.
# =======================================================================
_u_scenario niri
_run_util executable_start-niri --help
_u_expect "start_niri_help" 0 "Usage: start-niri"

_run_util executable_start-niri -h
_u_expect "start_niri_short_help" 0 "Usage: start-niri"

_run_util executable_start-niri --nope
_u_expect "start_niri_unknown_option_exits_2" 2 "Unknown option: --nope" "Usage: start-niri"

_run_util executable_start-niri
_u_expect "start_niri_without_niri_exits_127" 127 "start-niri requires niri"

_u_scenario niri_ok
_u_shim niri <<'EOF'
#!/usr/bin/env bash
printf 'niri desktop=%s session=%s ozone=%s\n' \
  "$XDG_CURRENT_DESKTOP" "$XDG_SESSION_DESKTOP" "$NIXOS_OZONE_WL"
exit 0
EOF
_run_util executable_start-niri
_u_expect "start_niri_execs_niri_with_wayland_env" 0 \
  "niri desktop=niri session=niri ozone=1"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
