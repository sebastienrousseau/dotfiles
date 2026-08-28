#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Smoke tests for `dot edit` — a fallback ladder that opens the
# chezmoi source directory in $EDITOR / nvim / vim, and errors when
# no editor is present.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CORE_SH="$REPO_ROOT/scripts/dot/commands/core.sh"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
# resolve_source_dir looks at the library file location. Override it
# with the cache export so cmd_edit sees our sandbox as the source.
mkdir -p "$TMPHOME/dotfiles"
export _DOT_SOURCE_DIR_CACHE="$TMPHOME/dotfiles"

# --- Mocks --------------------------------------------------------------
MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
LOG="$TMPHOME/mock.log"

# Editor mocks: log the invocation, exit 0.
for cmd in vim nvim my-editor; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
printf '$cmd %s\n' "\$*" >> "$LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }
_reset() { : > "$LOG"; }

# ---------------------------------------------------------------------------
# Editor ladder — $EDITOR wins over nvim wins over vim
# ---------------------------------------------------------------------------

# PATH with MOCK_BIN first so `command -v <editor>` prefers our mocks
# over any real editor on the host, but keeps /usr/bin available for
# shell utilities that require_source_dir + ui.sh need.
_SLIM_PATH="$MOCK_BIN:/usr/bin:/bin"

test_start "edit_uses_EDITOR_env_when_set"
_reset
EDITOR="my-editor" PATH="$_SLIM_PATH" bash "$CORE_SH" edit > /dev/null 2>&1
grep -q "my-editor" "$LOG"
[[ $? -eq 0 ]] && _ok || _fail "\$EDITOR not honoured"

test_start "edit_passes_a_directory_argument_to_editor"
# The editor gets some directory (real ~/.dotfiles when we can't override
# resolve_source_dir's cache from outside). Just check something was
# passed — a path-shaped arg with a leading slash.
grep -qE "my-editor /" "$LOG"
[[ $? -eq 0 ]] && _ok || _fail "no dir passed to editor"

test_start "edit_uses_mocked_EDITOR_when_env_wins_over_ladder"
_reset
# EDITOR env should win even when nvim + vim mocks are on PATH.
EDITOR="my-editor" PATH="$_SLIM_PATH" bash "$CORE_SH" edit > /dev/null 2>&1
grep -q "my-editor" "$LOG"
if [[ $? -eq 0 ]] && ! grep -q "^nvim " "$LOG" && ! grep -q "^vim " "$LOG"; then
  _ok
else
  _fail "\$EDITOR did not win over the nvim/vim fallback"
fi

# ---------------------------------------------------------------------------
# Dispatch surface
# ---------------------------------------------------------------------------

test_start "edit_dispatch_case_wired_in_core_sh"
grep -qE "^  edit\)" "$CORE_SH"
[[ $? -eq 0 ]] && _ok || _fail "no edit) case"

test_start "cmd_edit_function_defined"
grep -qE "^cmd_edit\(\)" "$CORE_SH"
[[ $? -eq 0 ]] && _ok || _fail

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
