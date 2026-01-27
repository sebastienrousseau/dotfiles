# Dotfiles Test Suite

A comprehensive shell testing framework for validating dotfiles functionality.

## Directory Structure

```
scripts/tests/
├── framework/
│   ├── test_runner.sh      # Main test runner
│   ├── assertions.sh       # Assert functions
│   └── mocks.sh            # Mock utilities
├── unit/
│   ├── test_extract.sh     # Tests for extract function
│   ├── test_backup.sh      # Tests for backup function
│   ├── test_genpass.sh     # Tests for genpass function
│   ├── test_rd.sh          # Tests for rd function
│   └── test_cd_aliases.sh  # Tests for cd aliases
├── integration/
│   └── test_install.sh     # Tests for install.sh
└── README.md               # This file
```

## Quick Start

### Run All Unit Tests

```bash
./scripts/tests/framework/test_runner.sh
```

### Run Specific Test

```bash
# Run only extract tests
./scripts/tests/framework/test_runner.sh extract

# Run only backup tests
./scripts/tests/framework/test_runner.sh backup

# Run only genpass tests
./scripts/tests/framework/test_runner.sh genpass
```

### Run with Integration Tests

```bash
# Using environment variable
RUN_INTEGRATION=1 ./scripts/tests/framework/test_runner.sh

# Using flag
./scripts/tests/framework/test_runner.sh -i
```

### Run Individual Test File

```bash
# Source assertions and run directly
source ./scripts/tests/framework/assertions.sh
source ./scripts/tests/unit/test_extract.sh
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
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

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

- Test files: `test_<functionality>.sh`
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

Located in `scripts/tests/unit/`. These test individual functions in isolation:

- **test_extract.sh** - Archive extraction function
- **test_backup.sh** - Backup creation function
- **test_genpass.sh** - Password generation function
- **test_rd.sh** - Directory removal function (with security tests)
- **test_cd_aliases.sh** - Directory navigation aliases

### Integration Tests

Located in `scripts/tests/integration/`. These test complete workflows:

- **test_install.sh** - Installation script validation

## CI/CD Integration

Add to your CI pipeline:

```yaml
# GitHub Actions example
- name: Run Tests
  run: |
    chmod +x ./scripts/tests/framework/test_runner.sh
    ./scripts/tests/framework/test_runner.sh

- name: Run Integration Tests
  run: |
    RUN_INTEGRATION=1 ./scripts/tests/framework/test_runner.sh
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
chmod +x scripts/tests/unit/test_*.sh
chmod +x scripts/tests/integration/test_*.sh
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

1. Create corresponding test file in `unit/`
2. Test happy path and error conditions
3. Include security-relevant test cases
4. Run full test suite before committing
