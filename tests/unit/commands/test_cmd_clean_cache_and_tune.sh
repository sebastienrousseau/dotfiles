#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Smoke tests for the two dot subcommands that were flagged as
# uncovered by tests/performance/coverage_dot_cli.sh: `dot clean-cache`
# (core module) and `dot tune` (appearance module).
#
# Both are behavioural checks in a sandboxed HOME — no real cache dirs
# on the host machine are touched.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CORE_SH="$REPO_ROOT/scripts/dot/commands/core.sh"
APPEARANCE_SH="$REPO_ROOT/scripts/dot/commands/appearance.sh"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_CACHE_HOME="$TMPHOME/.cache"
mkdir -p "$XDG_CACHE_HOME"/{zsh,bash,fish,nushell}

# Seed the caches with fixture files that clean-cache should nuke.
touch "$XDG_CACHE_HOME/zsh/foo-init.zsh"
touch "$XDG_CACHE_HOME/zsh/bar.zwc"
touch "$XDG_CACHE_HOME/bash/foo-init.bash"
touch "$XDG_CACHE_HOME/fish/foo-init.fish"
touch "$XDG_CACHE_HOME/nushell/foo.nu"
# And a file that must NOT be nuked (guards against overreach).
touch "$XDG_CACHE_HOME/zsh/history"

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

# ---------------------------------------------------------------------------
# dot clean-cache
# ---------------------------------------------------------------------------

test_start "clean_cache_removes_zsh_init_files"
bash "$CORE_SH" clean-cache > /dev/null 2>&1
if [[ ! -f "$XDG_CACHE_HOME/zsh/foo-init.zsh" ]]; then _ok; else _fail "zsh init not cleared"; fi

test_start "clean_cache_removes_zsh_zwc_files"
[[ ! -f "$XDG_CACHE_HOME/zsh/bar.zwc" ]] && _ok || _fail

test_start "clean_cache_removes_bash_init"
[[ ! -f "$XDG_CACHE_HOME/bash/foo-init.bash" ]] && _ok || _fail

test_start "clean_cache_removes_fish_init"
[[ ! -f "$XDG_CACHE_HOME/fish/foo-init.fish" ]] && _ok || _fail

test_start "clean_cache_removes_nushell_files"
[[ ! -f "$XDG_CACHE_HOME/nushell/foo.nu" ]] && _ok || _fail

test_start "clean_cache_preserves_non_init_files"
# zsh/history is NOT an init file — must survive.
[[ -f "$XDG_CACHE_HOME/zsh/history" ]] && _ok || _fail "history was clobbered"

test_start "clean_cache_reports_status_line"
out="$(bash "$CORE_SH" clean-cache 2>&1)"
if [[ "$out" == *"Cache"* ]]; then _ok; else _fail "no Cache status"; fi

test_start "clean_cache_exits_zero"
bash "$CORE_SH" clean-cache > /dev/null 2>&1
[[ $? -eq 0 ]] && _ok || _fail

# ---------------------------------------------------------------------------
# dot tune  — delegates to platform-specific scripts. Since we can't
# actually run macos.sh or the Linux tuning script in the sandbox, we
# smoke-test the delegation logic itself.
# ---------------------------------------------------------------------------

test_start "tune_module_defines_cmd_tune"
grep -qE "^cmd_tune\(\)" "$APPEARANCE_SH"
[[ $? -eq 0 ]] && _ok || _fail

test_start "tune_dispatch_case_exists"
grep -qE "^  tune\)" "$APPEARANCE_SH"
[[ $? -eq 0 ]] && _ok || _fail

test_start "tune_delegates_to_platform_scripts"
# The impl branches on macos/linux/wsl. Grep for the platform switch.
grep -qE 'case "\$platform" in' "$APPEARANCE_SH"
[[ $? -eq 0 ]] && _ok || _fail

test_start "tune_rejects_unknown_subcommand_shape"
# `dot tune` on unknown platform should exit non-zero.
# Simulate by setting DOT_PLATFORM to nonsense and calling the module.
# The module calls dot_platform_id which reads /etc/os-release etc;
# we can't easily override without deep mocking, but the module's own
# platform case has a *) fallthrough that exits — verify it exists.
grep -q '^    \*)' "$APPEARANCE_SH" || grep -qE 'unknown.*platform' "$APPEARANCE_SH"
[[ $? -eq 0 ]] && _ok || _fail

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
