#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI zsh completion

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

COMP_FILE="$REPO_ROOT/dot_local/share/zsh/completions/_dot"
DOT_FILE="$REPO_ROOT/dot_local/bin/executable_dot"

# Test: _dot completion file exists
test_start "dot_completion_file_exists"
assert_file_exists "$COMP_FILE" "_dot completion should exist"

# Test: has #compdef header
test_start "dot_completion_compdef_header"
if head -1 "$COMP_FILE" | grep -q '#compdef dot'; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has #compdef dot header"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have #compdef dot header"
fi

# Test: defines _dot function
test_start "dot_completion_function_defined"
if grep -q '_dot()' "$COMP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines _dot() function"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define _dot() function"
fi

# Test: includes core commands
test_start "dot_completion_core_commands"
missing=""
for cmd in apply sync update add diff status remove cd edit; do
  if ! grep -q "'$cmd:" "$COMP_FILE" 2>/dev/null; then
    missing="$missing $cmd"
  fi
done
if [[ -z "$missing" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all core commands present"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing core commands:$missing"
fi

# Test: includes diagnostic commands
test_start "dot_completion_diagnostic_commands"
missing=""
for cmd in doctor heal health rollback drift benchmark perf; do
  if ! grep -q "'$cmd:" "$COMP_FILE" 2>/dev/null; then
    missing="$missing $cmd"
  fi
done
if [[ -z "$missing" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all diagnostic commands present"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing diagnostic commands:$missing"
fi

# Test: includes security commands
test_start "dot_completion_security_commands"
missing=""
for cmd in backup firewall telemetry dns-doh encrypt-check lock-screen usb-safety; do
  if ! grep -q "'$cmd:" "$COMP_FILE" 2>/dev/null; then
    missing="$missing $cmd"
  fi
done
if [[ -z "$missing" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all security commands present"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing security commands:$missing"
fi

# Test: includes ssh-cert command
test_start "dot_completion_ssh_cert"
if grep -q "ssh-cert" "$COMP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: includes ssh-cert command"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should include ssh-cert command"
fi

# Test: ssh-cert has subcommand completion
test_start "dot_completion_ssh_cert_subcommands"
if grep -qE 'issue.*certificate|status.*certificate|revoke.*certificate' "$COMP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ssh-cert has subcommand completions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ssh-cert should have subcommand completions"
fi

# Test: new command has template completions
test_start "dot_completion_new_templates"
if grep -qE 'python.*go.*node' "$COMP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: new command has template completions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: new command should have template completions"
fi

# Test: perf command has flag completions
test_start "dot_completion_perf_flags"
if grep -q '\-\-json' "$COMP_FILE" 2>/dev/null && grep -q '\-\-precmd' "$COMP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: perf command has --json/--precmd completions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: perf should have flag completions"
fi

# Test: completion parity with dot help
test_start "dot_completion_parity_with_help"
# Extract subcommands from dot case statement
help_cmds=$(grep -oE '^\s+[a-z][-a-z]+\)' "$DOT_FILE" 2>/dev/null | \
  sed 's/[[:space:]]*//;s/)//' | sort -u)
missing_count=0
for cmd in $help_cmds; do
  if ! grep -q "'$cmd:" "$COMP_FILE" 2>/dev/null; then
    ((missing_count++))
  fi
done
# Allow some flexibility (help format may differ slightly)
if [[ "$missing_count" -le 3 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: completion covers most help commands"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $missing_count commands missing from completion"
fi

echo ""
echo "Dot CLI completion tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
