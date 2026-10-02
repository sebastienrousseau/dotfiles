#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for tuning scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

TUNING_DIR="$REPO_ROOT/scripts/tuning"

# Test: tuning directory exists
test_start "tuning_dir_exists"
assert_dir_exists "$TUNING_DIR" "tuning directory should exist"

# Test: linux.sh exists
test_start "tuning_linux_exists"
if [[ -f "$TUNING_DIR/linux.sh" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: linux.sh exists"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: linux.sh should exist"
fi

# Test: linux.sh valid syntax
test_start "tuning_linux_syntax"
if [[ -f "$TUNING_DIR/linux.sh" ]] && bash -n "$TUNING_DIR/linux.sh" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: linux.sh valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: linux.sh syntax errors"
fi

# Test: macos.sh exists
test_start "tuning_macos_exists"
if [[ -f "$TUNING_DIR/macos.sh" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: macos.sh exists"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: macos.sh should exist"
fi

# Test: macos.sh valid syntax
test_start "tuning_macos_syntax"
if [[ -f "$TUNING_DIR/macos.sh" ]] && bash -n "$TUNING_DIR/macos.sh" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: macos.sh valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: macos.sh syntax errors"
fi

# Recording stubs: sudo, defaults and killall log their arguments and never
# reach the host.
TUNE_WORK="$(mktemp -d -t dot-tuning.XXXXXX)"
trap 'rm -rf "$TUNE_WORK"' EXIT
mkdir -p "$TUNE_WORK/bin"
for stub in sudo defaults killall; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/calls.log"\ncat >/dev/null 2>&1 || true\n' \
    "$stub" "$TUNE_WORK" >"$TUNE_WORK/bin/$stub"
  chmod +x "$TUNE_WORK/bin/$stub"
done
tune_run() {
  rm -f "$TUNE_WORK/calls.log"
  tune_rc=0
  PATH="$TUNE_WORK/bin:/usr/bin:/bin" DOTFILES_TUNING=1 "$@" </dev/null >/dev/null 2>&1 || tune_rc=$?
  tune_calls="$(cat "$TUNE_WORK/calls.log" 2>/dev/null || true)"
}

# Test: linux.sh applies and persists sysctl settings through sudo
test_start "tuning_linux_sudo"
tune_run env DOTFILES_PROFILE=server bash "$TUNING_DIR/linux.sh"
assert_equals "0" "$tune_rc" "linux.sh exits 0"
assert_contains "sudo sysctl -w fs.inotify.max_user_watches=524288" "$tune_calls" "sysctl goes through sudo"
assert_contains "sudo tee /etc/sysctl.d/99-dotfiles.conf" "$tune_calls" "settings are persisted"
tune_run env DOTFILES_PROFILE=bogus bash "$TUNING_DIR/linux.sh"
assert_equals "1 " "$tune_rc $tune_calls" "an unknown profile exits 1 before any sudo"

# Test: macos.sh writes defaults and restarts Finder and the Dock
test_start "tuning_macos_defaults"
tune_run env DOTFILES_PROFILE=laptop bash "$TUNING_DIR/macos.sh"
assert_equals "0" "$tune_rc" "macos.sh exits 0"
assert_equals "defaults write -g InitialKeyRepeat -int 15" "$(printf '%s\n' "$tune_calls" | head -1)" "defaults is called"
assert_equals "killall Finder|killall Dock" "$(printf '%s\n' "$tune_calls" | grep '^killall' | paste -sd'|' -)" \
  "Finder and the Dock restart"
tune_run env DOTFILES_PROFILE= bash "$TUNING_DIR/macos.sh"
assert_equals "1 " "$tune_rc $tune_calls" "no profile exits 1 before any defaults write"

echo ""
echo "Tuning scripts tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
