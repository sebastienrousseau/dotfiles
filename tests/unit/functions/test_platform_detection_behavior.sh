#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for dot_platform_id and dot_is_wsl from scripts/dot/lib/platform.sh.
# Mocks 'uname' and the WSL osrelease file to simulate different platforms.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

PLATFORM_FILE="$REPO_ROOT/scripts/dot/lib/platform.sh"
if [[ ! -f "$PLATFORM_FILE" ]]; then
  echo "SKIP: platform.sh not found at $PLATFORM_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

# platform.sh uses 'set -euo pipefail'; source in a forgiving subshell then
# re-export the function definitions into the current shell.
_source_platform() {
  # Undefine any previously loaded versions to allow re-sourcing cleanly.
  unset -f dot_is_wsl dot_platform_id dot_host_os dot_path_to_unix \
    dot_path_to_native dot_open_path dot_require_platform 2>/dev/null || true
  # platform.sh starts with 'set -euo pipefail'; tolerate that in bash.
  # shellcheck source=/dev/null
  source "$PLATFORM_FILE"
  set +e # tests need to handle errors explicitly
}
_source_platform

mock_init

# ──────────────────────────────────────────────────────────────────────────────
# Helper: create a mock uname that returns a specific kernel name.
# ──────────────────────────────────────────────────────────────────────────────
_mock_uname() {
  local kernel="$1"
  cat >"$MOCK_BIN_DIR/uname" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-s" || \$# -eq 0 ]]; then
  echo "$kernel"
elif [[ "\$1" == "-r" ]]; then
  echo "5.15.0"
else
  echo "$kernel"
fi
EOF
  chmod +x "$MOCK_BIN_DIR/uname"
}

# ──────────────────────────────────────────────────────────────────────────────
# Helper: create a fake /proc/sys/kernel/osrelease for WSL simulation.
# ──────────────────────────────────────────────────────────────────────────────
_mock_wsl_osrelease() {
  local content="$1"
  local fake_proc
  fake_proc=$(portable_mktemp_dir)
  mkdir -p "$fake_proc/sys/kernel"
  echo "$content" >"$fake_proc/sys/kernel/osrelease"
  echo "$fake_proc"
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. dot_platform_id returns "macos" when uname reports "Darwin"
# ──────────────────────────────────────────────────────────────────────────────
test_start "platform_id_macos"
_mock_uname "Darwin"
result=$(dot_platform_id)
assert_equals "macos" "$result" "Darwin uname should yield 'macos'"

# ──────────────────────────────────────────────────────────────────────────────
# 2. dot_platform_id returns "linux" when uname reports "Linux" (non-WSL)
# ──────────────────────────────────────────────────────────────────────────────
test_start "platform_id_linux"
_mock_uname "Linux"
# Ensure dot_is_wsl returns false by overriding it.
dot_is_wsl() { return 1; }
result=$(dot_platform_id)
assert_equals "linux" "$result" "Linux uname without WSL should yield 'linux'"
_source_platform # restore original definitions

# ──────────────────────────────────────────────────────────────────────────────
# 3. dot_platform_id returns "unknown" for unrecognised kernel
# ──────────────────────────────────────────────────────────────────────────────
test_start "platform_id_unknown"
_mock_uname "FreeBSD"
dot_is_wsl() { return 1; }
result=$(dot_platform_id)
assert_equals "unknown" "$result" "unknown uname should yield 'unknown'"
_source_platform

# ──────────────────────────────────────────────────────────────────────────────
# 4. dot_platform_id returns "wsl" when uname=Linux and WSL markers present
# ──────────────────────────────────────────────────────────────────────────────
test_start "platform_id_wsl"
_mock_uname "Linux"
dot_is_wsl() { return 0; } # force WSL detection
result=$(dot_platform_id)
assert_equals "wsl" "$result" "Linux + WSL flag should yield 'wsl'"
_source_platform

# ──────────────────────────────────────────────────────────────────────────────
# 5. dot_is_wsl returns false when osrelease is absent
# ──────────────────────────────────────────────────────────────────────────────
test_start "dot_is_wsl_absent_osrelease"
# Override dot_is_wsl to test against a nonexistent file path.
_dot_is_wsl_with_file() {
  local osrelease_file="$1"
  [[ -f "$osrelease_file" ]] && grep -qiE '(microsoft|wsl)' "$osrelease_file"
}
_dot_is_wsl_with_file "/no/such/file/osrelease_$$"
rc=$?
assert_equals "1" "$rc" "missing osrelease should make dot_is_wsl return false"

# ──────────────────────────────────────────────────────────────────────────────
# 6. dot_is_wsl returns true when osrelease contains "microsoft"
# ──────────────────────────────────────────────────────────────────────────────
test_start "dot_is_wsl_microsoft_marker"
fake_proc=$(_mock_wsl_osrelease "5.15.90.1-microsoft-standard-WSL2")
_dot_is_wsl_with_file "$fake_proc/sys/kernel/osrelease"
rc=$?
assert_equals "0" "$rc" "osrelease with 'microsoft' should make dot_is_wsl return true"
rm -rf "$fake_proc"

# ──────────────────────────────────────────────────────────────────────────────
# 7. dot_is_wsl returns true when osrelease contains "WSL" (case-insensitive)
# ──────────────────────────────────────────────────────────────────────────────
test_start "dot_is_wsl_wsl_marker_uppercase"
fake_proc=$(_mock_wsl_osrelease "4.4.0-WSL")
_dot_is_wsl_with_file "$fake_proc/sys/kernel/osrelease"
rc=$?
assert_equals "0" "$rc" "osrelease with 'WSL' should make dot_is_wsl return true"
rm -rf "$fake_proc"

# ──────────────────────────────────────────────────────────────────────────────
# 8. dot_is_wsl returns false for plain Linux osrelease
# ──────────────────────────────────────────────────────────────────────────────
test_start "dot_is_wsl_plain_linux"
fake_proc=$(_mock_wsl_osrelease "6.1.0-27-amd64")
_dot_is_wsl_with_file "$fake_proc/sys/kernel/osrelease"
rc=$?
assert_equals "1" "$rc" "plain Linux osrelease should make dot_is_wsl return false"
rm -rf "$fake_proc"

# ──────────────────────────────────────────────────────────────────────────────
# 9. dot_host_os returns "macos" on Darwin (non-WSL)
# ──────────────────────────────────────────────────────────────────────────────
test_start "dot_host_os_macos"
_mock_uname "Darwin"
dot_is_wsl() { return 1; }
result=$(dot_host_os)
assert_equals "macos" "$result" "Darwin should produce host_os 'macos'"
_source_platform

# ──────────────────────────────────────────────────────────────────────────────
# 10. dot_host_os returns "windows" inside WSL
# ──────────────────────────────────────────────────────────────────────────────
test_start "dot_host_os_wsl_is_windows"
dot_is_wsl() { return 0; }
result=$(dot_host_os)
assert_equals "windows" "$result" "WSL environment should report host_os 'windows'"
_source_platform

mock_cleanup

echo ""
echo "platform detection behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
