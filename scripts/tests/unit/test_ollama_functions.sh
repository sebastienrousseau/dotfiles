#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Test Ollama functions functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Test setup
FUNCTIONS_FILE="$REPO_ROOT/dot_config/shell/custom/ollama_functions.zsh"

test_start "ollama_functions_file_exists"
assert_file_exists "$FUNCTIONS_FILE" "Ollama functions file should exist"

test_start "oq_function_with_valid_input"
mock_init
mock_command "ollama" "Mock ollama response for qwen-coder-ultra" 0

# Source functions in a subshell
(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  oq "test prompt"
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Mock ollama response" "oq should call ollama run qwen-coder-ultra with prompt"

rm -f /tmp/test_output
mock_cleanup

test_start "oq_function_without_input"
mock_init

(
  source "$FUNCTIONS_FILE"
  oq
) > /tmp/test_output 2>&1
exit_code=$?

assert_equals 1 "$exit_code" "oq should return exit code 1 without arguments"
assert_file_contains "/tmp/test_output" "Usage: oq" "oq should show usage without arguments"

rm -f /tmp/test_output
mock_cleanup

test_start "or1_function_with_valid_input"
mock_init
mock_command "ollama" "Mock ollama response for r1-ultra" 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  or1 "test prompt"
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Mock ollama response" "or1 should call ollama run r1-ultra with --think=false"

rm -f /tmp/test_output
mock_cleanup

test_start "or1_function_without_input"
mock_init

(
  source "$FUNCTIONS_FILE"
  or1
) > /tmp/test_output 2>&1
exit_code=$?

assert_equals 1 "$exit_code" "or1 should return exit code 1 without arguments"
assert_file_contains "/tmp/test_output" "Usage: or1" "or1 should show usage without arguments"

rm -f /tmp/test_output
mock_cleanup

test_start "or1t_function_with_valid_input"
mock_init
mock_command "ollama" "Mock ollama response for r1-ultra with thinking" 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  or1t "test prompt"
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Mock ollama response" "or1t should call ollama run r1-ultra with thinking enabled"

rm -f /tmp/test_output
mock_cleanup

test_start "or1d_function_with_valid_input"
mock_init
mock_command "ollama" "Mock ollama response for r1-deep" 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  or1d "test prompt"
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Mock ollama response" "or1d should call ollama run r1-deep"

rm -f /tmp/test_output
mock_cleanup

test_start "or1h_function_filters_thinking_tags"
mock_init
mock_command "ollama" $'Response\n<think>\nThinking content\n</think>\nFiltered response' 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  or1h "test prompt"
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Response" "or1h should include non-thinking content"
assert_file_contains "/tmp/test_output" "Filtered response" "or1h should include content after thinking tags"
assert_output_not_contains "Thinking content" "cat /tmp/test_output" "or1h should filter out thinking content"

rm -f /tmp/test_output
mock_cleanup

test_start "ol_warm_qwen_function"
mock_init
mock_command "ollama" "Model loaded" 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  ol-warm-qwen
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Warming up qwen-coder-ultra" "ol-warm-qwen should show warming message"
assert_file_contains "/tmp/test_output" "Ready!" "ol-warm-qwen should show ready message"

rm -f /tmp/test_output
mock_cleanup

test_start "ol_warm_r1_function"
mock_init
mock_command "ollama" "Model loaded" 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  ol-warm-r1
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Warming up r1-ultra" "ol-warm-r1 should show warming message"
assert_file_contains "/tmp/test_output" "Ready!" "ol-warm-r1 should show ready message"

rm -f /tmp/test_output
mock_cleanup

test_start "ollama_info_function_with_model"
mock_init
mock_command "ollama" "Modelfile content for test-model" 0

(
  export PATH="$MOCK_PATH:$PATH"
  source "$FUNCTIONS_FILE"

  ollama-info "test-model"
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Modelfile content" "ollama-info should call ollama show with --modelfile"

rm -f /tmp/test_output
mock_cleanup

test_start "ollama_info_function_without_model"
mock_init

(
  source "$FUNCTIONS_FILE"
  ollama-info
) > /tmp/test_output 2>&1
exit_code=$?

assert_equals 1 "$exit_code" "ollama-info should return exit code 1 without arguments"
assert_file_contains "/tmp/test_output" "Usage: ollama-info" "ollama-info should show usage without arguments"

rm -f /tmp/test_output
mock_cleanup

test_start "ollama_modelfiles_function"
mock_init
# Create a temporary directory to simulate ~/.ollama
test_ollama_dir=$(mock_dir "ollama")
mkdir -p "$test_ollama_dir"
touch "$test_ollama_dir/Modelfile.test1"
touch "$test_ollama_dir/Modelfile.test2"

(
  HOME=$(dirname "$test_ollama_dir")
  source "$FUNCTIONS_FILE"

  ollama-modelfiles
) > /tmp/test_output 2>&1

assert_file_contains "/tmp/test_output" "Custom Modelfiles" "ollama-modelfiles should show header"
assert_file_contains "/tmp/test_output" "test1" "ollama-modelfiles should list modelfiles"
assert_file_contains "/tmp/test_output" "test2" "ollama-modelfiles should list all modelfiles"

rm -f /tmp/test_output
mock_cleanup

test_start "functions_syntax_check"
assert_exit_code 0 "bash -n '$FUNCTIONS_FILE'" "Ollama functions file should have valid bash syntax"

test_start "functions_zsh_syntax_check"
if command -v zsh >/dev/null 2>&1; then
    assert_exit_code 0 "zsh -n '$FUNCTIONS_FILE'" "Ollama functions file should have valid zsh syntax"
else
    echo "SKIP: zsh not available"
fi

test_start "all_functions_defined"
(
  source "$FUNCTIONS_FILE"

  # Check all main functions are defined
  type oq >/dev/null 2>&1 && echo "oq_defined"
  type or1 >/dev/null 2>&1 && echo "or1_defined"
  type or1t >/dev/null 2>&1 && echo "or1t_defined"
  type or1d >/dev/null 2>&1 && echo "or1d_defined"
  type or1h >/dev/null 2>&1 && echo "or1h_defined"
  type ol-warm-qwen >/dev/null 2>&1 && echo "ol_warm_qwen_defined"
  type ol-warm-r1 >/dev/null 2>&1 && echo "ol_warm_r1_defined"
  type ol-warm-r1d >/dev/null 2>&1 && echo "ol_warm_r1d_defined"
  type ol-warm >/dev/null 2>&1 && echo "ol_warm_defined"
  type ollama-modelfiles >/dev/null 2>&1 && echo "ollama_modelfiles_defined"
  type ollama-info >/dev/null 2>&1 && echo "ollama_info_defined"
) > /tmp/test_output

assert_file_contains "/tmp/test_output" "oq_defined" "oq function should be defined"
assert_file_contains "/tmp/test_output" "or1_defined" "or1 function should be defined"
assert_file_contains "/tmp/test_output" "or1t_defined" "or1t function should be defined"
assert_file_contains "/tmp/test_output" "or1d_defined" "or1d function should be defined"
assert_file_contains "/tmp/test_output" "or1h_defined" "or1h function should be defined"
assert_file_contains "/tmp/test_output" "ol_warm_qwen_defined" "ol-warm-qwen function should be defined"
assert_file_contains "/tmp/test_output" "ol_warm_r1_defined" "ol-warm-r1 function should be defined"
assert_file_contains "/tmp/test_output" "ol_warm_r1d_defined" "ol-warm-r1d function should be defined"
assert_file_contains "/tmp/test_output" "ol_warm_defined" "ol-warm function should be defined"
assert_file_contains "/tmp/test_output" "ollama_modelfiles_defined" "ollama-modelfiles function should be defined"
assert_file_contains "/tmp/test_output" "ollama_info_defined" "ollama-info function should be defined"

rm -f /tmp/test_output