#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TARGET_SCRIPT="$REPO_ROOT/scripts/ops/post-apply-repair.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# Load functions without auto-running main.
DOTFILES_POST_APPLY_TESTING=1 source "$TARGET_SCRIPT"

LOG=""
ui_init() { :; }
ui_header() { :; }
ui_ok() { LOG+="OK|$1|${2:-}"$'\n'; }
ui_warn() { LOG+="WARN|$1|${2:-}"$'\n'; }
ui_err() { LOG+="ERR|$1|${2:-}"$'\n'; }

run_with_log() {
  LOG=""
  "$@" || true
}

test_start "repair_zwc_cache_no_changes"
clean_dir="$tmp_root/clean"
mkdir -p "$clean_dir"
DOTFILES_ZWC_CACHE_DIRS="$clean_dir" run_with_log repair_zwc_cache
assert_output_contains "no stale .zwc permissions detected" "printf '%s' \"$LOG\""

test_start "repair_zwc_cache_removes_readonly"
readonly_dir="$tmp_root/readonly"
mkdir -p "$readonly_dir"
touch "$readonly_dir/a.zwc"
chmod 444 "$readonly_dir/a.zwc"
DOTFILES_ZWC_CACHE_DIRS="$readonly_dir" run_with_log repair_zwc_cache
assert_output_contains "removed 1 stale read-only .zwc file(s)" "printf '%s' \"$LOG\""
test_start "repair_zwc_cache_file_removed"
assert_file_not_exists "$readonly_dir/a.zwc" "readonly .zwc should be removed"

test_start "repair_zwc_cache_remove_failure"
locked_dir="$tmp_root/locked"
mkdir -p "$locked_dir"
touch "$locked_dir/b.zwc"
chmod 444 "$locked_dir/b.zwc"
chmod 500 "$locked_dir"
DOTFILES_ZWC_CACHE_DIRS="$locked_dir" run_with_log repair_zwc_cache
assert_output_contains "failed to remove 1 stale .zwc file(s)" "printf '%s' \"$LOG\""
chmod 700 "$locked_dir"

test_start "validate_dot_cli_missing_binary"
home_missing="$tmp_root/home-missing"
mkdir -p "$home_missing"
HOME="$home_missing" DOTFILES_ZSH_BIN="" run_with_log validate_dot_cli
assert_output_contains "missing executable at $home_missing/.local/bin/dot" "printf '%s' \"$LOG\""

fake_zsh="$tmp_root/fake-zsh"
cat >"$fake_zsh" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "${DOTFILES_FAKE_ZSH_OUTPUT:-}"
EOF
chmod +x "$fake_zsh"

home_ok="$tmp_root/home-ok"
mkdir -p "$home_ok/.local/bin"
cat >"$home_ok/.local/bin/dot" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$home_ok/.local/bin/dot"

test_start "validate_dot_cli_no_zsh"
HOME="$home_ok" DOTFILES_ZSH_BIN="$tmp_root/missing-zsh" run_with_log validate_dot_cli
assert_output_contains "zsh not available; skipping shell validation" "printf '%s' \"$LOG\""

test_start "validate_dot_cli_resolution_ok"
HOME="$home_ok" DOTFILES_ZSH_BIN="$fake_zsh" DOTFILES_FAKE_ZSH_OUTPUT="$home_ok/.local/bin/dot" run_with_log validate_dot_cli
assert_output_contains "dot CLI resolution|$home_ok/.local/bin/dot" "printf '%s' \"$LOG\""

test_start "validate_dot_cli_alias_collision"
HOME="$home_ok" DOTFILES_ZSH_BIN="$fake_zsh" DOTFILES_FAKE_ZSH_OUTPUT=$'dot=\'cd_with_history "$HOME/.dotfiles"\'\n'"$home_ok/.local/bin/dot" run_with_log validate_dot_cli
assert_output_contains "legacy sessions may still map dot to navigation" "printf '%s' \"$LOG\""

test_start "validate_dot_cli_resolution_mismatch"
HOME="$home_ok" DOTFILES_ZSH_BIN="$fake_zsh" DOTFILES_FAKE_ZSH_OUTPUT=$'/usr/local/bin/dot' run_with_log validate_dot_cli
assert_output_contains "resolved to /usr/local/bin/dot (expected $home_ok/.local/bin/dot)" "printf '%s' \"$LOG\""

test_start "validate_dot_cli_resolution_missing"
HOME="$home_ok" DOTFILES_ZSH_BIN="$fake_zsh" DOTFILES_FAKE_ZSH_OUTPUT=$'' run_with_log validate_dot_cli
assert_output_contains "dot not found in a fresh zsh login shell" "printf '%s' \"$LOG\""

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
