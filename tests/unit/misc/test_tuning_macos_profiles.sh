#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Guard and apply tests for scripts/tuning/macos.sh.
#
# The script writes real macOS defaults and restarts Finder and the
# Dock, so the apply path runs with PATH pointing at recording shims
# for `defaults` and `killall`. Nothing reaches the host's preference
# store: the shims append their argv to a log the test then asserts on.

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

TUNING_FILE="$REPO_ROOT/scripts/tuning/macos.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
TBIN="$TMP/tune-bin"
CALLS="$TMP/tune-calls.log"
mkdir -p "$TBIN"
for tool in cat env printf sed grep tr locale tput dirname basename uname stty; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$TBIN/$tool"
done
ln -sf "$BASH" "$TBIN/bash"

for cmd in defaults killall; do
  cat >"$TBIN/$cmd" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$cmd" "\$*" >>"$CALLS"
exit 0
EOF
  chmod +x "$TBIN/$cmd"
done

# `env -i` gives each run a hermetic environment, but it would also drop
# BASH_ENV, which is how the repo's coverage runner turns on xtrace in
# child shells. Carry it through explicitly when it is set.
COV_ENV=(BASH_XTRACEFD=21)
[[ -n "${BASH_ENV:-}" ]] && COV_ENV+=("BASH_ENV=$BASH_ENV")

T_OUT=""
T_RC=0
_run_tuning() {
  T_RC=0
  : >"$CALLS"
  T_OUT="$(
    env -i "${COV_ENV[@]+"${COV_ENV[@]}"}" PATH="$TBIN" HOME="$TMP/tune-home" DOTFILES_ACCESSIBILITY=1 "$@" \
      "$BASH" "$TUNING_FILE" </dev/null 2>&1
  )" || T_RC=$?
}

_t_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$T_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $T_RC"
  for needle in "$@"; do
    [[ "$T_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$T_OUT" | sed 's/^/      /'
  fi
}

mkdir -p "$TMP/tune-home"

# =======================================================================
# 1. Opt-in guard: without DOTFILES_TUNING=1 the script is a no-op.
# =======================================================================
_run_tuning
_t_expect "tuning_is_opt_in" 0 "macOS Tuning" "disabled. Re-run with DOTFILES_TUNING=1"

test_start "opt_in_guard_writes_no_defaults"
if [[ ! -s "$CALLS" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: the disabled path must not touch defaults"
  sed 's/^/      /' "$CALLS"
fi

_run_tuning DOTFILES_TUNING=0
_t_expect "explicit_zero_is_still_disabled" 0 "disabled. Re-run with DOTFILES_TUNING=1"

# =======================================================================
# 2. Profile guard: an unset or unknown profile is a hard failure.
# =======================================================================
_run_tuning DOTFILES_TUNING=1
_t_expect "missing_profile_exits_1" 1 "DOTFILES_PROFILE" "not set to known profile"

_run_tuning DOTFILES_TUNING=1 DOTFILES_PROFILE=toaster
_t_expect "unknown_profile_exits_1" 1 "not set to known profile"

# =======================================================================
# 3. Apply path, once per accepted profile.
# =======================================================================
for profile in laptop desktop server; do
  _run_tuning DOTFILES_TUNING=1 "DOTFILES_PROFILE=$profile"
  _t_expect "apply_runs_for_${profile}_profile" 0 \
    "Applying" "macOS tuning" "macOS tuning" "complete"

  test_start "apply_for_${profile}_writes_expected_defaults"
  _missing=""
  while IFS= read -r expected; do
    grep -qF -- "$expected" "$CALLS" || _missing="${_missing}\n      missing call: $expected"
  done <<'EXPECTED'
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2
killall Finder
killall Dock
EXPECTED
  if [[ -z "$_missing" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$_missing"
    sed 's/^/      /' "$CALLS"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
