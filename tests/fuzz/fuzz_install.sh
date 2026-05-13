#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# fuzz_install.sh — input + environment fuzz harness for install.sh.
#
# Runs install.sh against a battery of adversarial inputs and
# environments, asserts it either succeeds cleanly OR fails fast with
# a clear non-zero exit. The goal is not to validate behavior of every
# code path — that's what tests/integration/test_install.sh does — but
# to catch the *crashes*: stack overflows on symlink loops, infinite
# retries when PATH is empty, silent-success on malformed args.
#
# Exit code: 0 if every fixture behaves as expected; 1 if any fixture
# triggers a hang, segfault, or unexpected behavior class.
#
# Regression for: GH-881
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
INSTALL_SH="$REPO_ROOT/install.sh"

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi

if [[ -z "$TIMEOUT_BIN" ]]; then
  echo "::warning::neither timeout nor gtimeout on PATH; skipping fuzz harness." >&2
  # Don't fail CI; the test is opt-in by environment.
  exit 0
fi

if [[ ! -f "$INSTALL_SH" ]]; then
  echo "::error::install.sh not found at $INSTALL_SH" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Fixture runner. Each fixture is a function that returns 0 on success.
# -----------------------------------------------------------------------------

PASS=0
FAIL=0
FAILED=()

declare -a TMP_PATHS=()
cleanup() {
  local p
  for p in "${TMP_PATHS[@]+"${TMP_PATHS[@]}"}"; do
    [[ -n "$p" && -e "$p" ]] && rm -rf -- "$p" 2>/dev/null || true
  done
}
trap cleanup EXIT

mktmpdir() {
  local d
  d=$(mktemp -d -t dotfiles-fuzz.XXXXXX)
  TMP_PATHS+=("$d")
  printf '%s\n' "$d"
}

run_fuzz() {
  local name="$1"; shift
  local expected_rc="$1"; shift
  local description="$1"; shift

  # The remaining args are env=value pairs and CLI args separated by `--`.
  local -a env_pairs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    env_pairs+=("$1")
    shift
  done
  [[ $# -gt 0 && "$1" == "--" ]] && shift
  local -a cli_args=("$@")

  printf '  %-40s ' "$name"

  local actual_rc=0
  # 30s cap. Use `env -i` to start from a clean env and add only what we want.
  if env -i HOME="${HOME}" PATH="${PATH}" ${env_pairs[@]+"${env_pairs[@]}"} \
      "$TIMEOUT_BIN" 30s \
      bash "$INSTALL_SH" "${cli_args[@]+"${cli_args[@]}"}" >/dev/null 2>&1; then
    actual_rc=0
  else
    actual_rc=$?
  fi

  # Treat any rc in the "expected" set as a pass. Special: -1 means "any
  # non-zero is acceptable, but timeout (rc 124) is a fail."
  case "$expected_rc" in
    "$actual_rc")
      PASS=$((PASS + 1))
      printf '✓ rc=%d  %s\n' "$actual_rc" "$description"
      ;;
    "nonzero")
      if [[ "$actual_rc" -ne 0 && "$actual_rc" -ne 124 ]]; then
        PASS=$((PASS + 1))
        printf '✓ rc=%d  %s\n' "$actual_rc" "$description"
      else
        FAIL=$((FAIL + 1))
        FAILED+=("$name (got rc=$actual_rc, expected non-zero non-timeout)")
        printf '✗ rc=%d  %s\n' "$actual_rc" "$description"
      fi
      ;;
    *)
      FAIL=$((FAIL + 1))
      FAILED+=("$name (got rc=$actual_rc, expected rc=$expected_rc)")
      printf '✗ rc=%d  %s\n' "$actual_rc" "$description"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Fixtures
# -----------------------------------------------------------------------------

echo "Fuzz harness — install.sh"
echo "─────────────────────────────────────"

# 1. Unknown long-option — should fail fast with usage hint.
run_fuzz "unknown_long_option" "nonzero" \
  "Unknown --flag should print usage and exit non-zero" \
  -- --this-flag-does-not-exist

# 2. Garbage positional — install.sh accepts no positional args.
run_fuzz "garbage_positional" "nonzero" \
  "Positional arg should be rejected or ignored cleanly" \
  -- garbage_arg

# 3. --help — should succeed and print usage.
run_fuzz "help_flag" "0" \
  "--help should exit zero" \
  -- --help

# 4. -h alias.
run_fuzz "help_short" "0" \
  "-h should exit zero" \
  -- -h

# 5. Empty $PATH — prerequisite check must catch missing git / curl.
run_fuzz "empty_path" "nonzero" \
  "Empty PATH should fail the prereq check, not crash" \
  PATH="" -- --help

# 6. Non-interactive + silent — the documented CI invocation must succeed
#    OR fail with a clear network/permission error, but never hang.
run_fuzz "noninteractive_help" "0" \
  "DOTFILES_NONINTERACTIVE=1 --help should still exit zero" \
  DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 -- --help

# 7. Symlink loop in HOME — install.sh walks $HOME; a self-referential
#    symlink should not trap it in an infinite loop. Use --help so we
#    just exercise the early prereq path without triggering an apply.
loop_home=$(mktmpdir)
ln -s "$loop_home" "$loop_home/loop"
run_fuzz "symlink_loop_home" "0" \
  "Symlink loop in HOME shouldn't hang install.sh --help" \
  HOME="$loop_home" -- --help

# 8. Doubled flag — duplicate --silent should be tolerated.
run_fuzz "duplicate_flag" "0" \
  "Duplicate --silent --silent should be tolerated" \
  DOTFILES_NONINTERACTIVE=1 -- --silent --silent --help

# 9. Long binary args — pathological string length.
big=$(printf 'x%.0s' $(seq 1 4096))
run_fuzz "huge_unknown_arg" "nonzero" \
  "Very long unknown arg should not buffer-overflow / hang" \
  -- "--$big"

# 10. NUL byte in arg — bash and most utilities reject NUL in arg list,
#     but install.sh should fail gracefully if it slips through env.
run_fuzz "nul_byte_env" "0" \
  "Strange env var should not affect --help path" \
  DOTFILES_PROFILE="laptop$(printf '\\x00')nasty" -- --help

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo "─────────────────────────────────────"
echo "Fuzz: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  for f in "${FAILED[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
exit 0
