#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Fall-back and failure paths of scripts/dot/commands/core.sh.
#
# Run from the checkout, core.sh always finds scripts/ops/chezmoi-*.sh and
# always execs those helpers, so the "no helper, talk to chezmoi directly"
# arms of apply/update/diff — and everything downstream of them — were never
# reached. This suite runs the module against a fixture source tree that
# carries no ops/ directory, with a PATH holding only the stubs each case
# wants found.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new core-paths)"
mkdir -p "$FX/home" "$FX/stubs"
dot_fixture_basebin "$FX/basebin"
DOT_FIXTURE_HOME="$FX/home"

# core.sh talks to chezmoi for everything the ops helpers would otherwise
# have handled. The stub echoes the subcommand so each case can prove which
# call was made.
dot_fixture_stub "$FX/stubs" chezmoi 0

core_run() {
  DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" dot_fixture_run "$FX" core "$@"
}

# ── 1. The direct-to-chezmoi arms ──────────────────────────────────────────
test_start "core_apply_falls_through_to_chezmoi"
core_run apply --dry-run
assert_equals "0" "$DOT_FIXTURE_RC" "apply should succeed without an ops helper"
assert_contains "chezmoi apply" "$DOT_FIXTURE_OUT" \
  "apply should exec chezmoi directly when no helper exists"

test_start "core_sync_is_an_alias_for_apply"
core_run sync
assert_contains "chezmoi apply" "$DOT_FIXTURE_OUT" "sync should route to apply"

test_start "core_update_falls_through_to_chezmoi"
core_run update
assert_equals "0" "$DOT_FIXTURE_RC" "update should succeed without an ops helper"
assert_contains "chezmoi update" "$DOT_FIXTURE_OUT" \
  "update should exec chezmoi directly when no helper exists"
assert_contains "Updating Dotfiles" "$DOT_FIXTURE_OUT" \
  "update should announce itself before handing over"

test_start "core_diff_falls_through_to_chezmoi"
core_run diff
assert_contains "chezmoi diff" "$DOT_FIXTURE_OUT" \
  "diff should exec chezmoi directly when no helper exists"

# ── 2. status surfaces a chezmoi failure instead of reading as clean ───────
test_start "core_status_reports_a_chezmoi_failure"
dot_fixture_stub "$FX/stubs" chezmoi 4
core_run status
assert_equals "4" "$DOT_FIXTURE_RC" "status should propagate chezmoi's status"
assert_contains "exited 4" "$DOT_FIXTURE_OUT" "the failure should name the status"
dot_fixture_stub "$FX/stubs" chezmoi 0

# ── 3. add without an argument is a usage error ────────────────────────────
test_start "core_add_requires_a_file"
core_run add
assert_equals "1" "$DOT_FIXTURE_RC" "add with no argument should exit 1"
assert_contains "Usage: dot add" "$DOT_FIXTURE_OUT" "it should print usage"

# ── 4. edit walks its editor preference list ───────────────────────────────
#
# EDITOR first, then nvim, then vim, then a usage error. Each case hides the
# ones above it by leaving them off the PATH.
test_start "core_edit_prefers_nvim_when_editor_is_unset"
dot_fixture_stub "$FX/stubs" nvim 0
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  EDITOR="" dot_fixture_run "$FX" core edit
assert_contains "nvim" "$DOT_FIXTURE_OUT" "edit should fall back to nvim"

test_start "core_edit_falls_back_to_vim"
rm -f "$FX/stubs/nvim"
dot_fixture_stub "$FX/stubs" vim 0
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  EDITOR="" dot_fixture_run "$FX" core edit
assert_contains "vim" "$DOT_FIXTURE_OUT" "edit should fall back to vim"

test_start "core_edit_reports_no_editor"
rm -f "$FX/stubs/vim"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  EDITOR="" dot_fixture_run "$FX" core edit
assert_equals "1" "$DOT_FIXTURE_RC" "edit with no editor at all should exit 1"
assert_contains "No editor found" "$DOT_FIXTURE_OUT" \
  "it should say which variable to set"

# ── 5. Delegating subcommands report a missing helper ──────────────────────
test_start "core_remove_reports_a_missing_helper"
core_run remove somefile
assert_equals "1" "$DOT_FIXTURE_RC" "remove without its helper should exit 1"
assert_contains "Remove helper not found" "$DOT_FIXTURE_OUT" \
  "the missing helper should be named"

test_start "core_uninstall_reports_a_missing_helper"
core_run uninstall
assert_equals "1" "$DOT_FIXTURE_RC" "uninstall without its helper should exit 1"
assert_contains "Uninstall script not found" "$DOT_FIXTURE_OUT" \
  "the missing helper should be named"

test_start "core_commit_reports_a_missing_helper"
core_run commit
assert_equals "1" "$DOT_FIXTURE_RC" "commit without its helper should exit 1"

# ── 6. clean-cache empties the per-shell cache directories ─────────────────
test_start "core_clean_cache_clears_shell_caches"
CACHE="$FX/home/.cache"
mkdir -p "$CACHE/zsh" "$CACHE/bash" "$CACHE/fish" "$CACHE/nushell"
: >"$CACHE/zsh/dot-init.zsh"
: >"$CACHE/bash/dot-init.bash"
: >"$CACHE/fish/dot-init.fish"
: >"$CACHE/nushell/dot.nu"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  XDG_CACHE_HOME="$CACHE" dot_fixture_run "$FX" core clean-cache
assert_equals "0" "$DOT_FIXTURE_RC" "clean-cache should exit 0"
assert_file_not_exists "$CACHE/zsh/dot-init.zsh" "the zsh cache should be gone"
assert_file_not_exists "$CACHE/nushell/dot.nu" "the nushell cache should be gone"

# ── 7. cd prints the resolved source directory ─────────────────────────────
test_start "core_cd_prints_the_source_directory"
core_run cd
assert_equals "0" "$DOT_FIXTURE_RC" "cd should exit 0"
assert_contains "dot-cov-fixtures/core-paths" "$DOT_FIXTURE_OUT" \
  "cd should print the fixture root"

print_summary
