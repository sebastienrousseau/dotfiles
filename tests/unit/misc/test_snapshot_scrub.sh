#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Why: CLI snapshots must not depend on host paths, versions, or health state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRUB="$REPO_ROOT/tests/snapshots/scrub.sh"

scrub_fixture() {
  local mode="$1"
  local fixture="$2"
  printf '%s\n' "$fixture" | bash "$SCRUB" "$mode"
}

test_start "snapshot_scrub_doctor_is_host_independent"
doctor_a=$'== Core Shells ==\n  ✓    zsh                                 /opt/homebrew/bin/zsh (custom)\n  ✓    fish                                /opt/homebrew/bin/fish\n== Platform ==\n  alice@mac-a\n  OS: macOS 26.4\n  Uptime: 1:23\n== State ==\n  ✗    chezmoi                             drifted'
doctor_b=$'== Core Shells ==\n  ✗    zsh                                 /usr/bin/zsh (system)\n== Platform ==\n  bob@mac-b\n  OS: Ubuntu 26.04\n== State ==\n  ✓    chezmoi                             clean'
assert_equals "$(scrub_fixture doctor "$doctor_a")" "$(scrub_fixture doctor "$doctor_b")" \
  "doctor snapshots normalize paths, host facts, and state"

test_start "snapshot_scrub_health_is_host_independent"
health_a=$'▸ Runtime\n──────────\n✓ Node.js (v24.1.0)                  OK\n✓ SSH key perms (id_rsa)              OK\n⚠ Chezmoi sync                        WARNING\n▸ Optional\n──────────\n✓ Hyperfine                          OK\n  Total checks:  45\n  Passed:        44\n  Warnings:      1\n  Failures:      0\n  Health Score: [#####.] 97%\n  Tip: repair it'
health_b=$'▸ Runtime\n──────────\n✓ Node.js (v26.0.0)                  OK\n✓ Chezmoi sync                        OK\n▸ Optional\n──────────\n  Total checks:  44\n  Passed:        44\n  Warnings:      0\n  Failures:      0\n  Health Score: [######] 100%'
assert_equals "$(scrub_fixture health "$health_a")" "$(scrub_fixture health "$health_b")" \
  "health snapshots normalize optional keys, versions, counts, and state"

test_start "snapshot_scrub_version_is_checkout_independent"
version_a=$'  ✓    Version                             .dotfiles 0.2.513\n  ✓    Source                              /Users/alice/.dotfiles'
version_b=$'  ✓    Version                             .dotfiles 0.2.999\n  ✓    Source                              /home/bob/src/dotfiles'
assert_equals "$(scrub_fixture version "$version_a")" "$(scrub_fixture version "$version_b")" \
  "version snapshots normalize release and checkout path"

test_start "snapshot_scrub_removes_ansi_before_duration_rules"
ansi_input=$'\033[0;34mseb@host\033[0m\nvalue 12ms   \n\n'
ansi_expected=$'seb@host\nvalue <dur>'
assert_equals "$ansi_expected" "$(scrub_fixture generic "$ansi_input")" \
  "ANSI fragments do not corrupt usernames and trailing whitespace is removed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
