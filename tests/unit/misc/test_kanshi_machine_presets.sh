#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The kanshi config picks a display profile from `machine`. It knew only its
# own names (surface-pro-7p, mac-t2-linux), not the [machines.*] presets in
# .chezmoidata/hardware.toml (surface-pro, macbook-t2), so a host set up
# with a preset name got no display profile. Each case renders the real
# template with chezmoi.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEMPLATE="$REPO_ROOT/defaults/dot_config/kanshi/config.tmpl"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-kanshi.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "  chezmoi unavailable: skipped"
  echo "RESULTS:0:0:0"
  exit 0
fi

# profiles MACHINE: the kanshi profiles rendered for that machine.
profiles() {
  printf '[data]\nmachine = "%s"\n' "$1" >"$WORK/chezmoi.toml"
  chezmoi --source "$REPO_ROOT/defaults" --config "$WORK/chezmoi.toml" \
    --destination "$WORK/home" execute-template <"$TEMPLATE" 2>/dev/null |
    awk '/^profile /{print $2}' | tr '\n' ' ' | sed 's/ $//'
}

test_start "each_hardware_preset_gets_its_display_profile"
for preset in $(sed -n 's/^\[machines\.\([a-z0-9-]*\)\]$/\1/p' "$REPO_ROOT/defaults/.chezmoidata/hardware.toml"); do
  assert_equals "2" "$(profiles "$preset" | wc -w | tr -d ' ')" "$preset: the undocked profile and its own"
done

test_start "the_presets_map_to_their_profiles"
assert_equals "undocked surface-internal" "$(profiles surface-pro)" "surface-pro"
assert_equals "undocked t2-internal" "$(profiles macbook-t2)" "macbook-t2"
assert_equals "undocked geekom-dual" "$(profiles geekom-a9)" "geekom-a9"

test_start "the_example_names_still_work"
assert_equals "undocked surface-internal" "$(profiles surface-pro-7p)" "surface-pro-7p"
assert_equals "undocked t2-internal" "$(profiles mac-t2-linux)" "mac-t2-linux"

test_start "no_machine_is_undocked_only"
assert_equals "undocked" "$(profiles "")" "no machine set"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
