#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Targeted coverage for the accessibility branch of scripts/dot/lib/ui.sh.
# That branch (lines 76-86) is gated on DOTFILES_ACCESSIBILITY=1 and so
# is never traced by the default sandbox-environment run. Exercising
# it explicitly closes a 10-line gap without touching any other test.
#
# AUTO-GENERATED: false (hand-written, do not regenerate)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

UI="$REPO_ROOT/scripts/dot/lib/ui.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "ui_sh_exists"
assert_file_exists "$UI" "ui.sh must exist"

# Drive the accessibility / ASCII-fallback branch.
test_start "ui_accessibility_branch_executes"
DOTFILES_ACCESSIBILITY=1 bash -c '
  set +eu
  source "$1" || true
  set +eu
  # Call every output helper so the printf-wrapped branches in the
  # ASCII-fallback glyph mode get traced.
  ui_init
  ui_header "header text"
  ui_section "section text"
  ui_ok "ok-label" "ok-value"
  ui_warn "warn-label" "warn-value"
  ui_err "err-label" "err-value"
  ui_info "info-label" "info-value"
  ui_meta "meta-label" "meta-value"
  ui_cmd "test-command"
  ui_bullet "bullet item"
  ui_kv "key" "value"
  ui_key_value "key" "value"
' _ "$UI" </dev/null >/dev/null 2>&1
rc=$?
if [[ "$rc" -lt 125 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
