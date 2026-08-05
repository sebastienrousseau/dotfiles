#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/switch.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
cat >"$DOTFILES_COV_TMPDIR/bin/dot-theme-sync" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"${DOTFILES_COV_TMPDIR:?}/theme-sync.log"
exit 0
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/dot-theme-sync"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "script should exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

test_start "theme_switch_deep_branches_execute"
for args in \
  "list" \
  "current" \
  "toggle" \
  "family" \
  "sync" \
  "altai-light"; do
  if DOTFILES_ACCESSIBILITY=1 DOTFILES_WALLPAPER_DIR="$HOME/Pictures/Wallpapers" bash "$SCRIPT_FILE" $args >/dev/null; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot theme $args"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot theme $args should execute"
  fi
done

test_start "theme_switch_linux_sync_branch_executes"
cat >"$DOTFILES_COV_TMPDIR/bin/uname" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  -s) echo "Linux" ;;
  -m) echo "x86_64" ;;
  *) echo "Linux" ;;
esac
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/uname"
cat >"$DOTFILES_COV_TMPDIR/bin/gsettings" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  get) echo "'prefer-light'" ;;
  *) : ;;
esac
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/gsettings"
if DOTFILES_ACCESSIBILITY=1 DOTFILES_WALLPAPER_DIR="$HOME/Pictures/Wallpapers" bash "$SCRIPT_FILE" sync >/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: Linux gsettings sync branch"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: Linux sync branch should execute"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
