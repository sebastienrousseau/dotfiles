# Dotfiles Test Suite

A comprehensive shell testing framework for validating dotfiles functionality.

## Directory Structure

```
tests/
├── framework/
│   ├── test_runner.sh      # Main test runner
│   ├── assertions.sh       # Assert functions
│   ├── mocks.sh            # Mock utilities
│   └── mock_os.sh          # OS detection mocks
├── unit/
│   ├── aliases/            # Alias tests
│   ├── functions/          # Function tests
│   ├── shell/              # Shell startup tests
│   ├── dot-cli/            # dot CLI tests
│   ├── ops/                # Operations tests
│   ├── diagnostics/        # Diagnostics tests
│   ├── security/           # Security tests
│   ├── fish/               # Fish shell tests
│   ├── nvim/               # Neovim config tests
│   ├── install/            # Installer tests
│   ├── theme/              # Theme tests
│   ├── tools/              # Tools tests
│   ├── secrets/            # Secrets tests
│   ├── nushell/            # Nushell tests
│   └── misc/               # Miscellaneous tests
├── integration/
│   └── test_*.sh           # End-to-end tests
├── performance/
│   └── *.sh                # Benchmarks
└── README.md               # This file
```

## Quick Start

### Run All Unit Tests

```bash
./tests/framework/test_runner.sh
```

### Run Specific Test

```bash
# Run only extract tests
./tests/framework/test_runner.sh extract

# Run only backup tests
./tests/framework/test_runner.sh backup

# Run only genpass tests
./tests/framework/test_runner.sh genpass
```

### Run with Integration Tests

```bash
# Using environment variable
RUN_INTEGRATION=1 ./tests/framework/test_runner.sh

# Using flag
./tests/framework/test_runner.sh -i
```

### Run Individual Test File

```bash
# Source assertions and run directly
source ./tests/framework/assertions.sh
source ./tests/unit/functions/test_extract.sh
print_summary
```

## Test Framework

### Assertions

The framework provides these assertion functions:

| Function | Description |
|----------|-------------|
| `assert_equals expected actual [msg]` | Assert two values are equal |
| `assert_not_equals unexpected actual [msg]` | Assert two values differ |
| `assert_exit_code code command` | Assert command exits with code |
| `assert_output_contains needle command` | Assert output contains string |
| `assert_output_not_contains needle command` | Assert output lacks string |
| `assert_output_matches pattern command` | Assert output matches regex |
| `assert_file_exists path [msg]` | Assert file exists |
| `assert_file_not_exists path [msg]` | Assert file doesn't exist |
| `assert_dir_exists path [msg]` | Assert directory exists |
| `assert_dir_not_exists path [msg]` | Assert directory doesn't exist |
| `assert_true condition [msg]` | Assert condition is true |
| `assert_false condition [msg]` | Assert condition is false |
| `assert_empty value [msg]` | Assert string is empty |
| `assert_not_empty value [msg]` | Assert string is not empty |
| `assert_file_contains file needle [msg]` | Assert file contains text |

### Mocks

The mock library provides utilities for test isolation:

| Function | Description |
|----------|-------------|
| `mock_init` | Initialize mock environment |
| `mock_command name output [exit_code]` | Create mock command |
| `mock_command_spy name [output] [exit_code]` | Create mock that records calls |
| `mock_get_calls name` | Get spy call history |
| `mock_call_count name` | Get number of spy calls |
| `mock_file content [filename]` | Create temp file with content |
| `mock_dir [prefix]` | Create temp directory |
| `mock_archive type [content]` | Create mock archive file |
| `mock_env var_name value` | Set environment variable |
| `mock_cleanup` | Clean up all mocks |

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

# Source function being tested
source "$REPO_ROOT/.chezmoitemplates/functions/myfunction.sh"

# Test case
test_start "my_function_basic"
output=$(myfunction "arg" 2>&1)
assert_equals "expected" "$output" "should return expected"

# Another test
test_start "my_function_error"
output=$(myfunction 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "should fail without args"
```

### Using Mocks

```bash
test_start "function_with_mock"
# Create temp directory
test_dir=$(mock_dir "test")
test_file="$test_dir/file.txt"
echo "content" > "$test_file"

# Run test
result=$(myfunction "$test_file")

# Verify
assert_equals "expected" "$result"

# Cleanup is automatic via trap
```

### Test Naming Convention

- Test files: `test_<domain>_<feature>.sh`
- Test functions: Descriptive names with `test_start`
- Example: `test_start "extract_handles_missing_file"`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_INTEGRATION` | `0` | Set to `1` to run integration tests |
| `VERBOSE` | `0` | Set to `1` for verbose output |
| `REPO_ROOT` | Auto-detected | Repository root directory |
| `TESTS_DIR` | Auto-detected | Tests directory |

## Test Categories

### Unit Tests

Located in `tests/unit/` organized by domain subdirectories. These test individual functions in isolation.

### Integration Tests

Located in `tests/integration/`. These test complete workflows.

## CI/CD Integration

Add to your CI pipeline:

```yaml
# GitHub Actions example
- name: Run Tests
  run: |
    chmod +x ./tests/framework/test_runner.sh
    ./tests/framework/test_runner.sh

- name: Run Integration Tests
  run: |
    RUN_INTEGRATION=1 ./tests/framework/test_runner.sh
```

## Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Use mocks that auto-cleanup via traps
3. **No Sleep**: Avoid `sleep` or hardcoded delays
4. **Descriptive Names**: Test names should describe what's being tested
5. **Edge Cases**: Test error conditions, not just happy paths
6. **Security**: Include tests for dangerous input rejection

## Troubleshooting

### Tests Not Found

Ensure test files match the pattern `test_*.sh` and are executable:

```bash
chmod +x tests/unit/*/test_*.sh
chmod +x tests/integration/test_*.sh
```

### Function Not Available

If a test shows "function not available", the source file may not exist:

```bash
# Check if function file exists
ls -la .chezmoitemplates/functions/
```

### Mock Cleanup Issues

If mocks aren't cleaning up, ensure you're not running with `set -e` before mock operations that might fail.

## Contributing

When adding new functions to the dotfiles:

1. Create corresponding test file in the appropriate `unit/<domain>/` subdirectory
2. Test happy path and error conditions
3. Include security-relevant test cases
4. Run full test suite before committing

---

Made with ❤️ by [Sebastien Rousseau](https://sebastienrousseau.com)
