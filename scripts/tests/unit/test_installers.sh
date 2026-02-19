#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for install/lib/installers.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

LOGGING_FILE="$REPO_ROOT/install/lib/logging.sh"
INSTALLERS_FILE="$REPO_ROOT/install/lib/installers.sh"

echo "Testing installers library..."

# Test: installers.sh exists
test_start "installers_file_exists"
assert_file_exists "$INSTALLERS_FILE" "installers.sh should exist"

# Test: installers.sh has valid syntax
test_start "installers_syntax"
assert_exit_code 0 "bash -n '$INSTALLERS_FILE'"

# Test: installers.sh has double-source guard
test_start "installers_guard"
assert_file_contains "$INSTALLERS_FILE" "_DOTFILES_INSTALLERS_LOADED" "should have double-source guard"

# Test: sha256_file computes checksum
test_start "sha256_file_computes"
tmp_file=$(mock_file "hello world")
output=$(bash -c '
  source "'"$LOGGING_FILE"'"
  source "'"$INSTALLERS_FILE"'"
  sha256_file "'"$tmp_file"'"
')
# sha256 of "hello world\n" is known
if [[ -n "$output" && ${#output} -eq 64 ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: sha256_file returns 64-char hash"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: sha256_file should return 64-char hash"
  echo -e "    Output: $output (length: ${#output})"
fi

# Test: resolve_arch returns valid architecture
test_start "resolve_arch_valid"
output=$(bash -c '
  source "'"$LOGGING_FILE"'"
  source "'"$INSTALLERS_FILE"'"
  resolve_arch
')
if [[ "$output" == "x86_64" || "$output" == "aarch64" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: resolve_arch returns $output"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: resolve_arch should return x86_64 or aarch64"
  echo -e "    Output: $output"
fi

# Test: resolve_sudo returns empty or "sudo"
test_start "resolve_sudo_returns"
output=$(bash -c '
  source "'"$LOGGING_FILE"'"
  source "'"$INSTALLERS_FILE"'"
  resolve_sudo
')
if [[ -z "$output" || "$output" == "sudo" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: resolve_sudo returns '$output'"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: resolve_sudo should return empty or 'sudo'"
  echo -e "    Output: $output"
fi

# Test: warn_unpinned dies on "latest" tag
test_start "warn_unpinned_dies_on_latest"
assert_exit_code 1 "bash -c 'source \"$LOGGING_FILE\"; source \"$INSTALLERS_FILE\"; warn_unpinned Test latest TEST_TAG'"

# Test: warn_unpinned dies on "nightly" tag
test_start "warn_unpinned_dies_on_nightly"
assert_exit_code 1 "bash -c 'source \"$LOGGING_FILE\"; source \"$INSTALLERS_FILE\"; warn_unpinned Test nightly TEST_TAG'"

# Test: warn_unpinned succeeds on pinned tag
test_start "warn_unpinned_ok_pinned"
assert_exit_code 0 "bash -c 'source \"$LOGGING_FILE\"; source \"$INSTALLERS_FILE\"; warn_unpinned Test v1.2.3 TEST_TAG'"

# Test: github_asset_url constructs fallback URL for tagged release
test_start "github_asset_url_tagged"
output=$(bash -c '
  source "'"$LOGGING_FILE"'"
  source "'"$INSTALLERS_FILE"'"
  github_asset_url "owner/repo" "binary-linux.tar.gz" "v1.0.0"
' 2>/dev/null)
if [[ "$output" == *"github.com"* && "$output" == *"v1.0.0"* && "$output" == *"binary-linux.tar.gz"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: github_asset_url returns correct tagged URL"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: github_asset_url should construct tagged URL"
  echo -e "    Output: $output"
fi

# Test: github_asset_url constructs fallback URL for latest release
test_start "github_asset_url_latest"
output=$(bash -c '
  source "'"$LOGGING_FILE"'"
  source "'"$INSTALLERS_FILE"'"
  github_asset_url "owner/repo" "binary.tar.gz" "latest"
' 2>/dev/null)
if [[ "$output" == *"github.com/owner/repo/releases/latest/download/binary.tar.gz"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: github_asset_url returns correct latest URL"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: github_asset_url should construct latest URL"
  echo -e "    Output: $output"
fi

# Test: download_and_verify_sha256 verifies matching checksum
test_start "download_verify_matching"
tmp_dir=$(mock_dir "verify_test")
echo "test file content" >"$tmp_dir/test.bin"
# Use sha256sum on Linux, shasum on macOS
if command -v sha256sum >/dev/null 2>&1; then
  expected_hash=$(sha256sum "$tmp_dir/test.bin" | awk '{print $1}')
else
  expected_hash=$(shasum -a 256 "$tmp_dir/test.bin" | awk '{print $1}')
fi
echo "$expected_hash  test.bin" >"$tmp_dir/test.bin.sha256"
# Create mock curl that copies local files
mock_init
cat >"$MOCK_BIN_DIR/curl" <<'SCRIPT'
#!/usr/bin/env bash
# Extract -o destination from args
dest=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) dest="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
if [[ -n "$dest" && -n "$url" && -f "$url" ]]; then
  cp "$url" "$dest"
fi
SCRIPT
chmod +x "$MOCK_BIN_DIR/curl"

result=$(bash -c '
  export PATH="'"$MOCK_BIN_DIR"':$PATH"
  source "'"$LOGGING_FILE"'"
  source "'"$INSTALLERS_FILE"'"
  download_and_verify_sha256 "'"$tmp_dir/test.bin"'" "'"$tmp_dir/test.bin.sha256"'" "'"$tmp_dir/downloaded.bin"'"
  echo "OK"
' 2>&1) || true
if [[ "$result" == *"OK"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: verify succeeds with matching checksum"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: verify should succeed with matching checksum"
  echo -e "    Output: $result"
fi

# Test: double-sourcing installers is idempotent
test_start "installers_idempotent"
assert_exit_code 0 "bash -c 'source \"$LOGGING_FILE\"; source \"$INSTALLERS_FILE\"; source \"$INSTALLERS_FILE\"; echo ok'"

print_summary
