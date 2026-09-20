#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural contract for theme plan/lock/snapshot/journal/rollback.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"
WORK="$(mktemp -d -t dot-theme-transaction.XXXXXX)"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_PYTHON="$(command -v python3)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export CHEZMOI_SOURCE_DIR="$WORK/source"
export DOT_THEME_STATE_DIR="$WORK/transactions"
export DOT_THEME_LOCK_ROOT="$WORK/locks"
export DOT_THEME_SEQUENTIAL=1
mkdir -p \
  "$HOME/.config/chezmoi" \
  "$HOME/.config/kitty" \
  "$HOME/.config/firefox" \
  "$CHEZMOI_SOURCE_DIR/.chezmoidata" \
  "$CHEZMOI_SOURCE_DIR/scripts/theme" \
  "$WORK/bin" "$DOT_THEME_LOCK_ROOT"
cp "$REPO_ROOT/scripts/theme/sync-ai-cli-themes.py" \
  "$CHEZMOI_SOURCE_DIR/scripts/theme/sync-ai-cli-themes.py"

cat >"$CHEZMOI_SOURCE_DIR/.chezmoidata.toml" <<'TOML'
theme = "baseline-dark"
theme_family = "baseline"
theme_mode = "dark"
TOML
cat >"$CHEZMOI_SOURCE_DIR/.chezmoidata/themes.toml" <<'TOML'
[themes.baseline-dark]
family = "baseline"
mode = "dark"

[themes.maui-dark]
family = "maui"
mode = "dark"

[themes.maui-light]
family = "maui"
mode = "light"
TOML
cat >"$HOME/.config/chezmoi/chezmoi.toml" <<'TOML'
[data]
theme = "baseline-dark"
theme_family = "baseline"
theme_mode = "dark"
TOML
printf 'original kitty config\n' >"$HOME/.config/kitty/kitty.conf"
printf 'original firefox config\n' >"$WORK/firefox-user.js"
ln -s "$WORK/firefox-user.js" "$HOME/.config/firefox/user.js"

cat >"$WORK/bin/uname" <<EOF
#!$REAL_BASH
printf 'Linux\n'
EOF
cat >"$WORK/bin/python3" <<EOF
#!$REAL_BASH
exec "$REAL_PYTHON" "\$@"
EOF
cat >"$WORK/bin/chezmoi" <<EOF
#!$REAL_BASH
for arg in "\$@"; do
  if [[ "\$arg" == "--dry-run" ]]; then
    exit "\${FAKE_CHEZMOI_RC:-0}"
  fi
done
printf 'rendered kitty config\n' >"$HOME/.config/kitty/kitty.conf"
rm -f "$HOME/.config/firefox/user.js"
printf 'rendered firefox config\n' >"$HOME/.config/firefox/user.js"
exit "\${FAKE_CHEZMOI_RC:-0}"
EOF
for tool in busctl pgrep tmux niri gsettings kwriteconfig6 qdbus nvim dms; do
  cat >"$WORK/bin/$tool" <<EOF
#!$REAL_BASH
exit 1
EOF
done
chmod +x "$WORK/bin/"*
export PATH="$WORK/bin:/usr/bin:/bin"

plan="$WORK/plan.json"
before_cfg="$(shasum -a 256 "$HOME/.config/chezmoi/chezmoi.toml" | awk '{print $1}')"
before_kitty="$(shasum -a 256 "$HOME/.config/kitty/kitty.conf" | awk '{print $1}')"
"$THEME_SYNC" maui-dark --plan --json >"$plan"

test_start "theme_plan_is_valid_json"
assert_exit_code 0 "'$REAL_PYTHON' -m json.tool '$plan' >/dev/null"

test_start "theme_plan_uses_versioned_contract"
assert_output_contains '1.0|theme.apply|maui-dark|dark' \
  "'$REAL_PYTHON' -c \"import json; p=json.load(open('$plan')); print(p['schema_version'], p['operation'], p['desired']['name'], p['desired']['mode'], sep='|')\""

test_start "theme_plan_schema_is_committed"
assert_file_exists "$REPO_ROOT/schemas/theme-plan.schema.json"

test_start "theme_journal_schema_is_committed"
assert_file_exists "$REPO_ROOT/schemas/theme-journal.schema.json"

test_start "theme_plan_does_not_create_transaction_state"
assert_dir_not_exists "$DOT_THEME_STATE_DIR" "planning must not create transaction state"

test_start "theme_plan_does_not_mutate_machine_state"
assert_equals "$before_cfg" "$(shasum -a 256 "$HOME/.config/chezmoi/chezmoi.toml" | awk '{print $1}')"

test_start "theme_plan_does_not_mutate_rendered_configs"
assert_equals "$before_kitty" "$(shasum -a 256 "$HOME/.config/kitty/kitty.conf" | awk '{print $1}')"

invalid_id_rc=0
DOT_THEME_OPERATION_ID="../escape" "$THEME_SYNC" maui-dark --force >/dev/null 2>&1 || invalid_id_rc=$?

test_start "transaction_rejects_path_traversal_operation_id"
assert_equals "1" "$invalid_id_rc"

test_start "invalid_operation_id_does_not_escape_state_root"
assert_dir_not_exists "$WORK/escape"

export FAKE_CHEZMOI_RC=1
export DOT_THEME_OPERATION_ID="rollback-case"
rollback_rc=0
"$THEME_SYNC" maui-dark --force >/dev/null 2>&1 || rollback_rc=$?

test_start "required_render_failure_is_nonzero"
assert_equals "1" "$rollback_rc"

test_start "required_render_failure_restores_machine_state"
assert_file_contains "$HOME/.config/chezmoi/chezmoi.toml" 'theme = "baseline-dark"'

test_start "required_render_failure_restores_rendered_config"
assert_file_contains "$HOME/.config/kitty/kitty.conf" "original kitty config"

test_start "required_render_failure_restores_symlink_type"
assert_exit_code 0 "test -L '$HOME/.config/firefox/user.js'"

test_start "required_render_failure_restores_symlink_target"
assert_equals "$WORK/firefox-user.js" "$(readlink "$HOME/.config/firefox/user.js")"

test_start "required_render_failure_writes_rollback_journal"
assert_file_contains "$DOT_THEME_STATE_DIR/rollback-case/journal.json" '"status": "rolled_back"'

test_start "rollback_releases_global_lock"
assert_dir_not_exists "$DOT_THEME_LOCK_ROOT/dot-theme-$(id -u).lock.d"

mkdir "$DOT_THEME_LOCK_ROOT/dot-theme-$(id -u).lock.d"
printf 'pid=%s\n' "$$" >"$DOT_THEME_LOCK_ROOT/dot-theme-$(id -u).lock.d/owner"
lock_rc=0
DOT_THEME_OPERATION_ID="lock-case" "$THEME_SYNC" maui-dark --force --lock-timeout 0 >/dev/null 2>&1 || lock_rc=$?

test_start "concurrent_theme_apply_is_rejected"
assert_equals "1" "$lock_rc"

test_start "lock_rejection_does_not_create_operation"
assert_dir_not_exists "$DOT_THEME_STATE_DIR/lock-case"

rm -f "$DOT_THEME_LOCK_ROOT/dot-theme-$(id -u).lock.d/owner"
rmdir "$DOT_THEME_LOCK_ROOT/dot-theme-$(id -u).lock.d"
export FAKE_CHEZMOI_RC=0
export DOT_THEME_OPERATION_ID="success-case"
mkdir -p "$HOME/.claude"
printf '%s\n' '{not-json' >"$HOME/.claude/settings.json"
invalid_provider_before="$(shasum -a 256 "$HOME/.claude/settings.json" | awk '{print $1}')"
success_rc=0
success_output="$WORK/success.out"
"$THEME_SYNC" maui-dark --force >"$success_output" 2>&1 || success_rc=$?
if [[ "$success_rc" -ne 0 ]]; then
  sed 's/^/    | /' "$success_output" >&2
fi

test_start "successful_transaction_exits_zero"
assert_equals "0" "$success_rc"

test_start "successful_transaction_commits_machine_state"
assert_file_contains "$HOME/.config/chezmoi/chezmoi.toml" 'theme = "maui-dark"'

test_start "successful_transaction_keeps_rendered_config"
assert_file_contains "$HOME/.config/kitty/kitty.conf" "rendered kitty config"

test_start "successful_transaction_writes_verified_journal"
assert_file_contains "$DOT_THEME_STATE_DIR/success-case/journal.json" '"status": "succeeded"'

test_start "optional_provider_failure_is_actionable"
assert_file_contains "$success_output" "claude=invalid_config"

test_start "optional_provider_failure_preserves_corrupt_config"
assert_equals "$invalid_provider_before" \
  "$(shasum -a 256 "$HOME/.claude/settings.json" | awk '{print $1}')"

switch_calls="$WORK/switch.calls"
cat >"$WORK/bin/dot-theme-sync" <<EOF
#!$REAL_BASH
printf '%s\n' "\$*" >"$switch_calls"
EOF
chmod +x "$WORK/bin/dot-theme-sync"
"$REAL_BASH" "$REPO_ROOT/scripts/theme/switch.sh" plan maui --mode auto --json >/dev/null

test_start "public_theme_plan_resolves_family_and_auto_mode"
assert_file_contains "$switch_calls" "maui-dark --plan --json --auto"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
