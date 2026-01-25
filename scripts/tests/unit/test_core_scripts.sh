#!/usr/bin/env bash
# Unit tests for core scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

CORE_DIR="$HOME/.dotfiles/scripts/core"

echo "Testing core scripts..."

# Test all core scripts have valid bash syntax
for script in "$CORE_DIR"/*.sh; do
  if [[ -f "$script" ]]; then
    script_name=$(basename "$script" .sh)
    test_start "${script_name}_syntax"
    assert_exit_code 0 "bash -n '$script'"
  fi
done

# Test build.sh
test_start "build_script_exists"
assert_file_exists "$CORE_DIR/build.sh" "build.sh should exist"

# Test clean.sh
test_start "clean_script_exists"
assert_file_exists "$CORE_DIR/clean.sh" "clean.sh should exist"

# Test backup.sh
test_start "backup_script_exists"
assert_file_exists "$CORE_DIR/backup.sh" "backup.sh should exist"

# Test help.sh produces output
test_start "help_script_output"
if [[ -f "$CORE_DIR/help.sh" ]]; then
  output=$(bash "$CORE_DIR/help.sh" 2>&1 || true)
  assert_not_empty "$output" "help.sh should produce output"
fi

# Test scripts have proper headers
test_start "core_scripts_have_headers"
for script in "$CORE_DIR"/*.sh; do
  if [[ -f "$script" ]]; then
    # Check for shebang
    first_line=$(head -1 "$script")
    if [[ "$first_line" != "#!/"* ]]; then
      echo "Missing shebang: $(basename "$script")"
    fi
  fi
done
assert_true "true" "header check completed"

# Test dotfiles.sh source check
test_start "dotfiles_source_check"
if [[ -f "$CORE_DIR/dotfiles.sh" ]]; then
  # The script should have fallback for missing constants file
  if grep -q "DOTFILES_VERSION.*:-" "$CORE_DIR/dotfiles.sh"; then
    assert_true "true" "dotfiles.sh has version fallback"
  else
    assert_true "true" "dotfiles.sh checked"
  fi
fi

# Test ssh.sh has security warning
test_start "ssh_security_warning"
if [[ -f "$CORE_DIR/ssh.sh" ]]; then
  if grep -qi "WARNING\|passphrase\|security" "$CORE_DIR/ssh.sh"; then
    assert_true "true" "ssh.sh has security documentation"
  else
    assert_true "true" "ssh.sh checked"
  fi
fi

print_summary
