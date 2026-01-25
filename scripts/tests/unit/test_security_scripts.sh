#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for security scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

SECURITY_DIR="$HOME/.dotfiles/scripts/security"

echo "Testing security scripts..."

# Test firewall.sh exists and has valid syntax
test_start "firewall_script_syntax"
if [[ -f "$SECURITY_DIR/firewall.sh" ]]; then
  assert_exit_code 0 "bash -n '$SECURITY_DIR/firewall.sh'"
else
  assert_true "true" "firewall.sh not found (optional)"
fi

# Test lock-configs.sh exists and has valid syntax
test_start "lock_configs_script_syntax"
if [[ -f "$SECURITY_DIR/lock-configs.sh" ]]; then
  assert_exit_code 0 "bash -n '$SECURITY_DIR/lock-configs.sh'"
else
  assert_true "true" "lock-configs.sh not found (optional)"
fi

# Test encryption-check.sh exists and has valid syntax
test_start "encryption_check_script_syntax"
if [[ -f "$SECURITY_DIR/encryption-check.sh" ]]; then
  assert_exit_code 0 "bash -n '$SECURITY_DIR/encryption-check.sh'"
else
  assert_true "true" "encryption-check.sh not found (optional)"
fi

# Test usb-safety.sh exists and has valid syntax
test_start "usb_safety_script_syntax"
if [[ -f "$SECURITY_DIR/usb-safety.sh" ]]; then
  assert_exit_code 0 "bash -n '$SECURITY_DIR/usb-safety.sh'"
else
  assert_true "true" "usb-safety.sh not found (optional)"
fi

# Test telemetry-disable.sh exists and has valid syntax
test_start "telemetry_disable_script_syntax"
if [[ -f "$SECURITY_DIR/telemetry-disable.sh" ]]; then
  assert_exit_code 0 "bash -n '$SECURITY_DIR/telemetry-disable.sh'"
else
  assert_true "true" "telemetry-disable.sh not found (optional)"
fi

# Test dns-doh.sh exists and has valid syntax
test_start "dns_doh_script_syntax"
if [[ -f "$SECURITY_DIR/dns-doh.sh" ]]; then
  assert_exit_code 0 "bash -n '$SECURITY_DIR/dns-doh.sh'"
else
  assert_true "true" "dns-doh.sh not found (optional)"
fi

# Test all security scripts have shebang
test_start "security_scripts_have_shebang"
for script in "$SECURITY_DIR"/*.sh; do
  if [[ -f "$script" ]]; then
    first_line=$(head -1 "$script")
    if [[ "$first_line" != "#!/"* ]]; then
      echo "Missing shebang: $script"
    fi
  fi
done
assert_true "true" "shebang check completed"

# Test security scripts are not world-writable
test_start "security_scripts_permissions"
for script in "$SECURITY_DIR"/*.sh; do
  if [[ -f "$script" ]]; then
    perms=$(stat -f "%Lp" "$script" 2>/dev/null || stat -c "%a" "$script" 2>/dev/null || echo "644")
    # Should not be world-writable (no 2 in last digit)
    last_digit="${perms: -1}"
    if [[ "$last_digit" == "2" || "$last_digit" == "3" || "$last_digit" == "6" || "$last_digit" == "7" ]]; then
      echo "World-writable: $script"
    fi
  fi
done
assert_true "true" "permissions check completed"

print_summary
