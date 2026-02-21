#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Tests for 10-secrets.sh compatibility in bash and zsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

SECRETS_FILE="$REPO_ROOT/dot_config/shell/10-secrets.sh.tmpl"

test_start "secrets_autoload_file_exists"
assert_file_exists "$SECRETS_FILE" "10-secrets template should exist"

make_dot_stub() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  cat <<'STUB' >"$tmp_dir/dot"
#!/usr/bin/env sh
if [ "$1" = "env" ] && [ "$2" = "load" ]; then
  # Emit nothing; caller evals output.
  exit 0
fi
exit 0
STUB
  chmod +x "$tmp_dir/dot"
  echo "$tmp_dir"
}

tmp_stub_dir="$(make_dot_stub)"

# Test: sourcing in bash should not error

test_start "secrets_autoload_bash"
assert_exit_code 0 "DOTFILES_SECRETS_AUTO_LOAD=1 DOTFILES_SECRETS_BUCKET_NAMES='a,b' PATH='$tmp_stub_dir:$PATH' bash -c 'source \"$SECRETS_FILE\"'"

# Test: sourcing in zsh should not error (if available)
if command -v zsh >/dev/null 2>&1; then
  test_start "secrets_autoload_zsh"
  assert_exit_code 0 "DOTFILES_SECRETS_AUTO_LOAD=1 DOTFILES_SECRETS_BUCKET_NAMES='a,b' PATH='$tmp_stub_dir:$PATH' zsh -c 'source \"$SECRETS_FILE\"'"
else
  test_start "secrets_autoload_zsh"
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: zsh not available, skipped"
fi

rm -rf "$tmp_stub_dir"

echo ""
echo "Secrets autoload tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
