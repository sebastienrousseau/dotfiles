#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Shared helpers for tests/unit/commands/ and tests/integration/.
#
# Every command-smoke test file in the tree repeats the same shape:
#   * _ok / _fail counters that print with the standard glyphs
#   * A substring assertion that sidesteps assert_output_contains's
#     eval-your-second-arg trap
#   * A sandbox setup routine with the full XDG env override
#   * A PATH-mocks builder for gsettings / kwriteconfig / dot-theme-sync
#   * A canonical "run a command module in a subshell" wrapper
#
# Sourcing this file exposes those helpers so new command tests
# stay short (~40-80 lines each) and consistent.
#
# Usage:
#   source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"
#
# shellcheck shell=bash

# Re-source guard: assertions.sh already establishes GREEN / RED / NC,
# TESTS_RUN / TESTS_PASSED / TESTS_FAILED, and test_start.
[[ "${_DOT_CMD_TEST_HELPERS_LOADED:-0}" == "1" ]] && return 0
_DOT_CMD_TEST_HELPERS_LOADED=1

# ---------------------------------------------------------------------------
# _ok / _fail — increment counters and print with the framework glyphs.
# Every command test in the tree was reinventing these; using the
# shared version keeps the output shape identical and cuts ~5 lines
# per test file.
# ---------------------------------------------------------------------------
_ok() {
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "${1:-$CURRENT_TEST}"
}

_fail() {
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "${1:-$CURRENT_TEST}" "${2:-}"
}

_skip() {
  ((TESTS_PASSED++)) || true
  printf '  \033[0;33m~\033[0m %s (%s)\n' "${1:-$CURRENT_TEST}" "${2:-skipped}"
}

# ---------------------------------------------------------------------------
# _contains — substring match on a captured string. Sidesteps
# assertions.sh's assert_output_contains which uses eval on its second
# arg and choked on ANSI escape sequences + unicode markers our UI
# helpers emit.
# ---------------------------------------------------------------------------
_contains() {
  local needle="$1" haystack="$2" msg="${3:-output should contain}"
  if [[ "$haystack" == *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s: %s '\''%s'\''\n' "$CURRENT_TEST" "$msg" "$needle"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: expected '\''%s'\''\n' "$CURRENT_TEST" "$needle"
    printf '    Actual: %s\n' "$haystack" | head -3
    return 1
  fi
}

# ---------------------------------------------------------------------------
# _cmd_sandbox_init — set up an isolated $HOME with all four XDG
# base-directory vars pointed at it. Every command test that touches
# systemd user units / config caches / state files needs this to avoid
# leaking into the real user's ~/.config.
#
# After the call, these globals are set:
#   TMPHOME      — the sandbox root
#   MOCK_BIN     — an on-PATH mock-binary directory (empty initially)
#   MOCK_LOG     — a log file every mock appends to (see _cmd_mock)
# ---------------------------------------------------------------------------
_cmd_sandbox_init() {
  TMPHOME="$(mktemp -d)"
  export HOME="$TMPHOME"
  export XDG_STATE_HOME="$TMPHOME/state"
  export XDG_CONFIG_HOME="$TMPHOME/.config"
  export XDG_DATA_HOME="$TMPHOME/.local/share"
  export XDG_CACHE_HOME="$TMPHOME/.cache"
  mkdir -p "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" \
           "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

  MOCK_BIN="$TMPHOME/mocks"
  MOCK_LOG="$TMPHOME/mock.log"
  mkdir -p "$MOCK_BIN"
  : > "$MOCK_LOG"
  # Prepend so mocks win over real binaries.
  export PATH="$MOCK_BIN:$PATH"
}

_cmd_sandbox_teardown() {
  [[ -n "${TMPHOME:-}" ]] && [[ -d "$TMPHOME" ]] && rm -rf "$TMPHOME"
}

# ---------------------------------------------------------------------------
# _cmd_mock — install a mock binary in MOCK_BIN. It logs every call
# to MOCK_LOG (`<name> <args>` per invocation) and exits 0. Additional
# custom body can be supplied as the second arg for special cases.
#
# Usage:
#   _cmd_mock gsettings
#   _cmd_mock sunwait "case \$1 in list) echo 06:00 ;; esac"
#   _cmd_mock chezmoi "exit 1"
# ---------------------------------------------------------------------------
_cmd_mock() {
  local name="$1"
  local body="${2:-}"
  local path="$MOCK_BIN/$name"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s %%s\\n" "%s" "$*" >> "%s"\n' "$name" "$MOCK_LOG"
    [[ -n "$body" ]] && printf '%s\n' "$body"
    printf 'exit 0\n'
  } > "$path"
  chmod +x "$path"
}

_cmd_mock_bulk() {
  for name in "$@"; do _cmd_mock "$name"; done
}

_cmd_reset_log() { : > "${MOCK_LOG:-/dev/null}"; }

# ---------------------------------------------------------------------------
# _cmd_seed_dotfiles_source — write a minimal fake dotfiles tree that
# scripts calling resolve_source_dir / CHEZMOI_SOURCE_DIR will accept.
# Puts a bare .chezmoidata.toml and (optionally) themes.toml in place.
# ---------------------------------------------------------------------------
_cmd_seed_dotfiles_source() {
  local themes_toml="${1:-}"
  mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
  export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
  touch "$TMPHOME/dotfiles/.chezmoidata.toml"
  if [[ -n "$themes_toml" && -f "$themes_toml" ]]; then
    cp "$themes_toml" "$TMPHOME/dotfiles/.chezmoidata/themes.toml"
  else
    touch "$TMPHOME/dotfiles/.chezmoidata/themes.toml"
  fi
}

# ---------------------------------------------------------------------------
# _cmd_run_module — invoke a scripts/dot/commands/<mod>.sh in a
# subshell, capturing stdout+stderr to a file the caller can inspect.
# Usage:
#   out="$(_cmd_run_module secrets secrets-init --help)"
# ---------------------------------------------------------------------------
_cmd_run_module() {
  local module="$1"; shift
  local module_file
  module_file="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/scripts/dot/commands/${module}.sh"
  if [[ ! -f "$module_file" ]]; then
    printf 'module not found: %s\n' "$module_file" >&2
    return 1
  fi
  ( bash "$module_file" "$@" )
}

# ---------------------------------------------------------------------------
# _cmd_asserts_defined / _cmd_asserts_case_exists — the two most
# repeated shell greps in every command test. Extracted so a new test
# file can be a series of one-liners.
# ---------------------------------------------------------------------------
_cmd_asserts_defined() {
  local file="$1" fn="$2"
  test_start "${fn}_defined"
  if grep -qE "^${fn}\(\)" "$file"; then _ok; else _fail "no ^${fn}() in $(basename "$file")"; fi
}

_cmd_asserts_case_exists() {
  local file="$1" label="$2"
  test_start "case_${label}_in_$(basename "$file" .sh)"
  # Accept 2-space indented case labels like `  set)` or
  # 2-space indent + alternation like `  set|reset)`.
  if grep -qE "^  ${label}[|)]" "$file"; then _ok; else _fail "no  ${label}) case"; fi
}

# ---------------------------------------------------------------------------
# _cmd_finish — emit the standard summary line + RESULTS: marker that
# tests/framework/test_runner.sh consumes for aggregate counts, and
# return the right exit code.
# ---------------------------------------------------------------------------
_cmd_finish() {
  echo ""
  printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
    "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  [[ $TESTS_FAILED -eq 0 ]]
}
