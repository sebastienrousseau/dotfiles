#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2030,SC2031
# Test AI aliases functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Test setup
ALIASES_FILE="$REPO_ROOT/.chezmoitemplates/aliases/ai/ai.aliases.sh"

test_start "ai_aliases_file_exists"
assert_file_exists "$ALIASES_FILE" "AI aliases file should exist"

test_start "github_copilot_aliases_when_gh_available"
mock_init
# Mock gh command as available
mock_command "gh" "gh 2.42.0" 0

# Source aliases in a subshell with expand_aliases enabled
(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR:$PATH"
  source "$ALIASES_FILE"

  # Check aliases are defined using alias command
  alias ghcp >/dev/null 2>&1 && echo "ghcp_defined"
  alias ghs >/dev/null 2>&1 && echo "ghs_defined"
  alias ghe >/dev/null 2>&1 && echo "ghe_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "ghcp_defined" "ghcp alias should be defined when gh available"
assert_file_contains "/tmp/test_output" "ghs_defined" "ghs alias should be defined when gh available"
assert_file_contains "/tmp/test_output" "ghe_defined" "ghe alias should be defined when gh available"

rm -f /tmp/test_output
mock_cleanup

test_start "github_copilot_aliases_when_gh_unavailable"
mock_init
# Use empty mock dir as PATH to ensure real gh isn't found
# (command -v, source, alias are builtins - don't need PATH)

(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR"
  source "$ALIASES_FILE"

  # Check aliases are NOT defined
  alias ghcp >/dev/null 2>&1 || echo "ghcp_not_defined"
  alias ghs >/dev/null 2>&1 || echo "ghs_not_defined"
  alias ghe >/dev/null 2>&1 || echo "ghe_not_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "ghcp_not_defined" "ghcp alias should not be defined when gh unavailable"
assert_file_contains "/tmp/test_output" "ghs_not_defined" "ghs alias should not be defined when gh unavailable"
assert_file_contains "/tmp/test_output" "ghe_not_defined" "ghe alias should not be defined when gh unavailable"

rm -f /tmp/test_output
mock_cleanup

test_start "fabric_alias_when_fabric_available"
mock_init
mock_command "fabric" "fabric v1.0.0" 0

(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR:$PATH"
  source "$ALIASES_FILE"

  alias fab >/dev/null 2>&1 && echo "fab_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "fab_defined" "fab alias should be defined when fabric available"

rm -f /tmp/test_output
mock_cleanup

test_start "fabric_alias_when_fabric_unavailable"
mock_init
# Use empty mock dir as PATH to ensure real fabric isn't found

(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR"
  source "$ALIASES_FILE"

  alias fab >/dev/null 2>&1 || echo "fab_not_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "fab_not_defined" "fab alias should not be defined when fabric unavailable"

rm -f /tmp/test_output
mock_cleanup

test_start "ollama_aliases_when_ollama_available"
mock_init
mock_command "ollama" "ollama version 1.0.0" 0

(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR:$PATH"
  source "$ALIASES_FILE"

  alias ol >/dev/null 2>&1 && echo "ol_defined"
  alias olr >/dev/null 2>&1 && echo "olr_defined"
  alias oll >/dev/null 2>&1 && echo "oll_defined"
  alias olp >/dev/null 2>&1 && echo "olp_defined"
  alias ollama-status >/dev/null 2>&1 && echo "ollama_status_defined"
  alias ollama-show >/dev/null 2>&1 && echo "ollama_show_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "ol_defined" "ol alias should be defined when ollama available"
assert_file_contains "/tmp/test_output" "olr_defined" "olr alias should be defined when ollama available"
assert_file_contains "/tmp/test_output" "oll_defined" "oll alias should be defined when ollama available"
assert_file_contains "/tmp/test_output" "olp_defined" "olp alias should be defined when ollama available"
assert_file_contains "/tmp/test_output" "ollama_status_defined" "ollama-status alias should be defined when ollama available"
assert_file_contains "/tmp/test_output" "ollama_show_defined" "ollama-show alias should be defined when ollama available"

rm -f /tmp/test_output
mock_cleanup

test_start "ollama_aliases_when_ollama_unavailable"
mock_init
# Use empty mock dir as PATH to ensure real ollama isn't found

(
  shopt -s expand_aliases
  export PATH="$MOCK_BIN_DIR"
  source "$ALIASES_FILE"

  alias ol >/dev/null 2>&1 || echo "ol_not_defined"
  alias olr >/dev/null 2>&1 || echo "olr_not_defined"
  alias oll >/dev/null 2>&1 || echo "oll_not_defined"
  alias olp >/dev/null 2>&1 || echo "olp_not_defined"
  alias ollama-status >/dev/null 2>&1 || echo "ollama_status_not_defined"
  alias ollama-show >/dev/null 2>&1 || echo "ollama_show_not_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "ol_not_defined" "ol alias should not be defined when ollama unavailable"
assert_file_contains "/tmp/test_output" "olr_not_defined" "olr alias should not be defined when ollama unavailable"
assert_file_contains "/tmp/test_output" "oll_not_defined" "oll alias should not be defined when ollama unavailable"
assert_file_contains "/tmp/test_output" "olp_not_defined" "olp alias should not be defined when ollama unavailable"
assert_file_contains "/tmp/test_output" "ollama_status_not_defined" "ollama-status alias should not be defined when ollama unavailable"
assert_file_contains "/tmp/test_output" "ollama_show_not_defined" "ollama-show alias should not be defined when ollama unavailable"

rm -f /tmp/test_output
mock_cleanup

test_start "aliases_syntax_check"
assert_exit_code 0 "bash -n '$ALIASES_FILE'"

test_start "aliases_shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    assert_exit_code 0 "shellcheck '$ALIASES_FILE'"
else
    echo "SKIP: shellcheck not available"
fi
