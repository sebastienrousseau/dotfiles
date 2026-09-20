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

test_start "tmux_status_exists"
assert_file_exists "$TMUX_STATUS" "tmux status helper must exist"

test_start "tmux_status_assigns_unique_wallpaper_colours"
TMUX_STATUS_TEST_LOG="$SANDBOX/colours.log" \
  PATH="$SANDBOX/bin:$PATH" \
  bash "$TMUX_STATUS" apply-colours '#60daee' '#61b9f2' '#ef8ee9'
assigned="$(wc -l <"$SANDBOX/colours.log" | tr -d ' ')"
unique="$(cut -d '|' -f2 "$SANDBOX/colours.log" | sort -u | wc -l | tr -d ' ')"
assert_equals "4" "$assigned" "every active session receives a color"
assert_equals "4" "$unique" "active sessions avoid color collisions"

test_start "tmux_status_shortens_context"
assert_equals "Public/project" \
  "$(bash "$TMUX_STATUS" short-path /Users/seb/Code/Public/project)" \
  "working directory context contains only two path components"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
