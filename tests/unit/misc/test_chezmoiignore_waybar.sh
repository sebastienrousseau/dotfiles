#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# waybar is a Wayland bar: its config stays off macOS and Windows, and on
# Linux it deploys as before (hosts rely on it without the reserved
# features.waybar flag). The real .chezmoiignore template is rendered per OS.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ignore-waybar.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "  chezmoi unavailable: skipped"
  echo "RESULTS:0:0:0"
  exit 0
fi
printf '[data]\n' >"$WORK/chezmoi.toml"

# ignored OS: "yes" when the rendered ignore list holds .config/waybar.
ignored() {
  chezmoi --source "$REPO_ROOT/defaults" --config "$WORK/chezmoi.toml" --destination "$WORK/home" \
    --override-data "{\"chezmoi\":{\"os\":\"$1\"}}" execute-template \
    <"$REPO_ROOT/defaults/.chezmoiignore.tmpl" 2>/dev/null |
    grep -qx '\.config/waybar' && echo yes || echo no
}

test_start "waybar_stays_off_macos_and_windows"
assert_equals "yes" "$(ignored darwin)" "macOS ignores .config/waybar"
assert_equals "yes" "$(ignored windows)" "Windows ignores it too"

test_start "waybar_deploys_on_linux"
assert_equals "no" "$(ignored linux)" "Linux deploys it, flag or not"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
