#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Behavioural coverage for small function templates whose remaining
# branches depend on the host: goto (cd + listing), size (Linux
# `stat -c` branch via a uname/stat shim) and utils/logging.sh (colour
# escapes only when stdout is a TTY, exercised through a pseudo-tty).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep bash xtrace flowing to the coverage runner's trace stream even
# when a probe below captures 2>&1 or runs under a pty.
exec 21>&2
export BASH_XTRACEFD=21

FUNCS_DIR="$REPO_ROOT/defaults/.chezmoitemplates/functions"
PY3="$(command -v python3 || true)"
REAL_STAT="$(command -v stat)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# run_pty <cmd...> — run under a pseudo-terminal so [ -t 1 ] is true.
run_pty() {
  "$PY3" -c 'import pty, sys; sys.exit(pty.spawn(sys.argv[1:]) >> 8)' "$@" </dev/null
}

# ── goto ─────────────────────────────────────────────────────────
target="$DOTFILES_COV_TMPDIR/goto-target"
mkdir -p "$target"
touch "$target/marker"

test_start "goto_changes_directory_and_lists"
out="$(bash -c 'source "$1"; goto "$2" >/dev/null 2>&1; pwd -L' _ "$FUNCS_DIR/nav/goto.sh" "$target" 2>&1)"
assert_equals "$target" "$out" "cwd is the requested directory afterwards"

test_start "goto_rejects_missing_directory"
out="$(bash -c 'source "$1"; goto "$2"' _ "$FUNCS_DIR/nav/goto.sh" "$target/nope" 2>&1)"
assert_equals 1 "$?" "missing directory exits 1"
assert_contains "is not a valid directory" "$out" "error explains"

test_start "goto_no_arg_and_help"
out="$(bash -c 'source "$1"; goto ""' _ "$FUNCS_DIR/nav/goto.sh" 2>&1)"
assert_contains "No directory provided" "$out" "empty arg rejected"
out="$(bash -c 'source "$1"; goto --help' _ "$FUNCS_DIR/nav/goto.sh" 2>&1)"
assert_contains "goto: Change Directory Helper" "$out" "help printed"

# ── size ─────────────────────────────────────────────────────────
size_bin="$DOTFILES_COV_TMPDIR/size-shims"
mkdir -p "$size_bin"
cat >"$size_bin/uname" <<'EOF'
#!/usr/bin/env bash
echo "${SIZE_TEST_UNAME:-Linux}"
EOF
cat >"$size_bin/stat" <<EOF
#!/usr/bin/env bash
# Deterministic byte counts for both stat dialects; anything else goes
# to the real stat so error paths still fail naturally.
case "\${1:-}" in
  -c) [[ -e "\${3:-}" ]] && echo 42 ;;
  -f) [[ -e "\${3:-}" ]] && echo 7 ;;
  *) exec "$REAL_STAT" "\$@" ;;
esac
EOF
chmod +x "$size_bin/uname" "$size_bin/stat"
sample="$DOTFILES_COV_TMPDIR/sample.bin"
echo "sample" >"$sample"

test_start "size_linux_branch_uses_stat_c"
out="$(PATH="$size_bin:$PATH" SIZE_TEST_UNAME=Linux bash -c 'source "$1"; size "$2"' _ "$FUNCS_DIR/files/size.sh" "$sample" 2>&1)"
assert_equals 0 "$?" "size exits 0"
assert_contains "Total size: 42 bytes" "$out" "Linux stat -c result reported"

test_start "size_darwin_branch_uses_stat_f"
out="$(PATH="$size_bin:$PATH" SIZE_TEST_UNAME=Darwin bash -c 'source "$1"; size "$2"' _ "$FUNCS_DIR/files/size.sh" "$sample" 2>&1)"
assert_contains "Total size: 7 bytes" "$out" "Darwin stat -f result reported"

test_start "size_missing_file_and_arg_count"
out="$(PATH="$size_bin:$PATH" bash -c 'source "$1"; size "$2"' _ "$FUNCS_DIR/files/size.sh" "$sample.missing" 2>&1)"
assert_equals 1 "$?" "missing file exits 1"
assert_contains "Could not determine size" "$out" "missing file reported"
out="$(bash -c 'source "$1"; size' _ "$FUNCS_DIR/files/size.sh" 2>&1)"
assert_equals 1 "$?" "no-arg exits 1"

# ── logging ──────────────────────────────────────────────────────
LOG_FILE="$FUNCS_DIR/utils/logging.sh"
log_probe='source "$1"; log_info i; log_success s; log_warning w; log_error e 2>&1'
esc=$'\033'

test_start "logging_colours_when_stdout_is_tty"
if [[ -n "$PY3" ]]; then
  out="$(NO_COLOR='' run_pty bash -c "$log_probe" _ "$LOG_FILE" 2>&1)"
  assert_contains "${esc}[0;34m[INFO]${esc}[0m i" "$out" "blue INFO escape"
  assert_contains "${esc}[0;32m[SUCCESS]" "$out" "green SUCCESS escape"
  assert_contains "${esc}[0;33m[WARN]" "$out" "yellow WARN escape"
  assert_contains "${esc}[0;31m[ERROR]" "$out" "red ERROR escape"
else
  echo "  SKIP: python3 not available for pty probe"
fi

test_start "logging_plain_when_not_a_tty"
out="$(NO_COLOR='' bash -c "$log_probe" _ "$LOG_FILE" 2>&1)"
assert_equals $'[INFO] i\n[SUCCESS] s\n[WARN] w\n[ERROR] e' "$out" "no escapes on a pipe"

test_start "logging_respects_no_color_on_tty"
if [[ -n "$PY3" ]]; then
  out="$(NO_COLOR=1 run_pty bash -c "$log_probe" _ "$LOG_FILE" 2>&1)"
  assert_contains "[INFO] i" "$out" "message still printed"
  if [[ "$out" == *"$esc"* ]]; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: escapes present despite NO_COLOR"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: NO_COLOR suppresses escapes"
  fi
else
  echo "  SKIP: python3 not available for pty probe"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
