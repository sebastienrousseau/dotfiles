#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Validates all new utility scripts — existence, syntax, structure
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BIN_DIR="$REPO_ROOT/dot_local/bin"

# All new scripts created in this session
SCRIPTS=(
  executable_gl
  executable_gd
  executable_gbd
  executable_dot-launch-or-focus
  executable_monitor
  executable_pw
  executable_dtags
  executable_mkscript
  executable_rec-start
  executable_rec-stop
)

for script in "${SCRIPTS[@]}"; do
  name="${script#executable_}"

  # --- Exists ---
  test_start "${name}_exists"
  assert_file_exists "$BIN_DIR/$script" "$name must exist"

  # --- Valid syntax ---
  test_start "${name}_syntax"
  if bash -n "$BIN_DIR/$script" 2>/dev/null; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  fi

  # --- Has shebang ---
  test_start "${name}_shebang"
  first_line=$(head -1 "$BIN_DIR/$script")
  if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST — got: $first_line"
  fi

  # --- Has copyright ---
  test_start "${name}_copyright"
  assert_file_contains "$BIN_DIR/$script" "Copyright" "$name must have copyright header"

  # --- Has set -euo pipefail or set -o errexit ---
  test_start "${name}_strict_mode"
  if grep -q 'set -euo pipefail\|set -o errexit' "$BIN_DIR/$script"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  fi
done

# --- Script-specific validations ---

test_start "gl_uses_fzf"
assert_file_contains "$BIN_DIR/executable_gl" "fzf" "gl must use fzf"

test_start "gl_uses_delta"
assert_file_contains "$BIN_DIR/executable_gl" "delta" "gl must use delta"

test_start "gl_supports_side_mode"
assert_file_contains "$BIN_DIR/executable_gl" "side" "gl must support --side"

test_start "gd_uses_fzf"
assert_file_contains "$BIN_DIR/executable_gd" "fzf" "gd must use fzf"

test_start "gbd_has_dry_run"
assert_file_contains "$BIN_DIR/executable_gbd" "dry-run" "gbd must support --dry-run"

test_start "gbd_protects_main"
assert_file_contains "$BIN_DIR/executable_gbd" "main|master" "gbd must whitelist main/master"

test_start "dot_launch_or_focus_uses_niri"
assert_file_contains "$BIN_DIR/executable_dot-launch-or-focus" "niri msg" "must use niri IPC"

test_start "monitor_detects_gpu"
assert_file_contains "$BIN_DIR/executable_monitor" "nvtop" "must detect GPU tools"

test_start "pw_uses_cb"
assert_file_contains "$BIN_DIR/executable_pw" "cb" "pw must use cb for clipboard"

test_start "dtags_queries_docker_hub"
assert_file_contains "$BIN_DIR/executable_dtags" "registry.hub.docker.com" "dtags must query Docker Hub"

test_start "mkscript_creates_executable"
assert_file_contains "$BIN_DIR/executable_mkscript" "chmod +x" "mkscript must set executable"

test_start "rec_start_backs_up_histfile"
assert_file_contains "$BIN_DIR/executable_rec-start" "HISTFILE" "rec-start must handle HISTFILE"

test_start "rec_stop_restores_histfile"
assert_file_contains "$BIN_DIR/executable_rec-stop" "HISTFILE" "rec-stop must handle HISTFILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
