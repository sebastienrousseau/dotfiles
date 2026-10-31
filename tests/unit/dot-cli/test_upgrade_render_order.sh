#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# `dot system update` hands the terminal to the step renderer between
# ui_steps_begin and ui_steps_end, so anything else written there lands in
# the middle of its drawing. cmd_upgrade runs here with the renderer
# replaced by markers on one stream: inside BEGIN..END only STEP lines may
# appear, and the AI pin bumps are listed after END. DOTFILES_APP_STORES=0
# turns the app-store phase into a visible skip on a machine whose store
# CLI does not work. mise and mas are fakes, and so is the dot that answers
# `dot ai update --check` with the bumps; nothing reaches a network.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-upgrade-render.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
for tool in mise mas; do
  printf '#!/bin/sh\nexit 0\n' >"$WORK/bin/$tool"
  chmod +x "$WORK/bin/$tool"
done
printf 'npm:@openai/codex 0.162.1 -> 0.163.0\n' >"$WORK/bumps.txt"
cat >"$WORK/bin/dot" <<EOF
#!/bin/sh
[ "\$*" = "ai update --check" ] || exit 2
cat "$WORK/bumps.txt"
EOF
chmod +x "$WORK/bin/dot"

# cmd_upgrade and its _upgrade_* helpers, as system.sh defines them.
awk '/^(_upgrade_[a-z_]+|cmd_upgrade)\(\) \{/,/^\}/' \
  "$REPO_ROOT/plugins/system/libexec/system.sh" >"$WORK/cmd_upgrade.sh"

# upgrade [VAR=value...]: one cmd_upgrade run; prints the marker stream.
upgrade() {
  env PATH="$WORK/bin:/usr/bin:/bin" TMPDIR="$WORK" DOTFILES_NO_TUI=1 NO_COLOR=1 \
    DOT_SYSTEM_DOT="$WORK/bin/dot" FAKES="$WORK/bin" "$@" bash -c '
    set -euo pipefail
    source "$1/lib/dot/ui.sh"
    source "$1/plugins/system/libexec/system/upgrade.sh"
    source "$2"
    require_source_dir() { printf "%s\n" "$FAKES"; }
    has_command() { [[ -x "$FAKES/$1" ]]; }
    chezmoi() { [[ "$1" == source-path ]] && echo /nonexistent || echo applied; }
    dot_upgrade_prepare() { DOT_UPGRADE_SYSTEM="${SYSTEM:-}"; }
    _dot_upgrade_mise() { echo "mise done"; }
    _dot_upgrade_system() { echo "system done"; }
    _dot_upgrade_apps() { echo "apps done"; }
    ui_steps_begin() { echo BEGIN; }
    ui_steps_end() { echo END; }
    ui_step() { echo "STEP $1 $3 ${4:-}"; }
    ui_info() { echo "INFO $1 ${2:-}"; }
    cmd_upgrade' _ "$REPO_ROOT" "$WORK/cmd_upgrade.sh" 2>&1
}

# inside STREAM: the lines between BEGIN and END that are not step events.
inside() { awk '/^BEGIN$/ { on = 1; next } /^END$/ { on = 0 } on && !/^STEP /' <<<"$1"; }
# after STREAM: the lines after END.
after() { awk 'done { print } /^END$/ { done = 1 }' <<<"$1"; }

test_start "nothing_but_steps_inside_the_render"
out="$(upgrade)"
assert_equals "" "$(inside "$out")" "only step events reach the renderer: $(inside "$out" | head -n 2)"

test_start "pin_bumps_are_a_step"
assert_contains "STEP pins ok 1 newer release" "$out" "the check runs as a step that counts the bumps"

test_start "pin_bumps_are_listed_after_the_render"
assert_contains "INFO Pin bump npm:@openai/codex 0.162.1 -> 0.163.0" "$(after "$out")" "each bump is listed once the renderer is done"
assert_contains "[ai_tools]" "$(after "$out")" "and says where the pins are edited"

test_start "no_bump_no_list"
: >"$WORK/bumps.txt"
out="$(upgrade)"
assert_contains "STEP pins ok every pin is current" "$out" "the step says so"
assert_output_not_contains "Pin bump" "printf '%s' '$out'" "and nothing is listed"

test_start "app_stores_run_with_system_packages"
out="$(upgrade SYSTEM=brew)"
assert_contains "STEP apps run" "$out" "the app-store phase runs after consented system packages"

test_start "app_stores_can_be_turned_off"
out="$(upgrade SYSTEM=brew DOTFILES_APP_STORES=0)"
assert_output_not_contains "STEP apps run" "printf '%s' '$out'" "DOTFILES_APP_STORES=0 never runs a store"
assert_contains "STEP apps skip" "$out" "the phase shows as a skip"
assert_contains "DOTFILES_APP_STORES=0" "$out" "naming the setting that turned it off"
assert_equals "" "$(inside "$out")" "and still nothing but steps inside the render"
assert_contains "END" "$out" "and the update carries on to the end"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
