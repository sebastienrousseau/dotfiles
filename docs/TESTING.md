# Testing Strategy

## Overview

This repository uses a comprehensive multi-layer testing approach:
- **Unit Tests**: Individual function validation
- **Integration Tests**: System-wide behavior verification
- **Performance Tests**: Resource efficiency benchmarks

## Running Tests

### Quick Start
```bash
# Run all unit tests
./scripts/tests/framework/test_runner.sh

# Run specific test suite
./scripts/tests/framework/test_runner.sh extract

# Run integration tests
RUN_INTEGRATION=1 ./scripts/tests/framework/test_runner.sh

# Run performance benchmarks
./scripts/tests/performance/benchmark_runner.sh
```

## Test Structure

```
scripts/tests/
├── framework/           # Test framework
│   ├── assertions.sh    # 15+ assertion functions
│   ├── mocks.sh        # Mock utilities
│   └── test_runner.sh  # Test executor
├── unit/               # Unit tests
├── integration/        # Integration tests
└── performance/        # Benchmarks
```

## Writing Tests

### Test File Template
```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source function under test
source "$HOME/.dotfiles/.chezmoitemplates/functions/myfunction.sh"

# Test cases
test_start "function_basic_usage"
assert_exit_code 0 "myfunction arg1"

test_start "function_no_args"
assert_exit_code 1 "myfunction"
```

### Available Assertions

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

### Mock Utilities

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

## Coverage Goals

| Category | Target | Current |
|----------|--------|---------|
| Functions | >80% | ~85% |
| Scripts | >70% | ~75% |
| Integration | >90% | ~95% |

## CI Integration

Tests run automatically on:
- Every push to main/master
- Every pull request
- Weekly scheduled runs (Monday 6 AM UTC)

### GitHub Actions Example

```yaml
- name: Run Tests
  run: |
    chmod +x ./scripts/tests/framework/test_runner.sh
    ./scripts/tests/framework/test_runner.sh

- name: Run Integration Tests
  run: |
    RUN_INTEGRATION=1 ./scripts/tests/framework/test_runner.sh

- name: Run Performance Benchmarks
  run: |
    ./scripts/tests/performance/benchmark_runner.sh
```

## Test Categories

### Unit Tests (`scripts/tests/unit/`)

Test individual functions in isolation:

- **test_extract.sh** - Archive extraction function
- **test_backup.sh** - Backup creation function
- **test_genpass.sh** - Password generation function
- **test_rd.sh** - Directory removal function (with security tests)
- **test_cd_aliases.sh** - Directory navigation aliases

### Integration Tests (`scripts/tests/integration/`)

Test complete workflows:

- **test_install.sh** - Installation script validation

### Performance Tests (`scripts/tests/performance/`)

Measure resource efficiency:

- **benchmark_runner.sh** - Shell startup and operation benchmarks
- **stress_test.sh** - Load testing utilities

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_INTEGRATION` | `0` | Set to `1` to run integration tests |
| `VERBOSE` | `0` | Set to `1` for verbose output |
| `REPO_ROOT` | Auto-detected | Repository root directory |
| `TESTS_DIR` | Auto-detected | Tests directory |

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

If a test shows "function not available", verify the source file exists:

```bash
ls -la .chezmoitemplates/functions/
```

### Mock Cleanup Issues

If mocks aren't cleaning up, ensure you're not running with `set -e` before mock operations that might fail.
