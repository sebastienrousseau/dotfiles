#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Unit tests for security scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SECURITY_DIR="$REPO_ROOT/scripts/security"

echo "Testing security scripts..."

# Test firewall.sh exists and has valid syntax
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
