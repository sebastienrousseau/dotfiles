# Testing strategy

## Overview

The repo uses a multi-layer testing approach: unit tests for individual functions, integration tests for system-wide behavior, and performance benchmarks for resource efficiency.

## Quick start

```bash
# Run all unit tests
./tests/framework/test_runner.sh

# Run a specific test suite
./tests/framework/test_runner.sh extract

# Run integration tests
RUN_INTEGRATION=1 ./tests/framework/test_runner.sh

# Run performance benchmarks
./tests/performance/benchmark_runner.sh
```

## Test structure

```text
tests/
├── framework/           # Test framework
│   ├── assertions.sh    # 16 assertion functions
│   ├── mocks.sh        # Mock utilities
│   └── test_runner.sh  # Test executor
├── unit/               # 425 unit test files
├── integration/        # 11 integration test files
└── performance/        # Benchmarks
```

## Writing tests

### Test file template

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function under test
source "$HOME/.dotfiles/.chezmoitemplates/functions/myfunction.sh"

# Test cases
test_start "function_basic_usage"
assert_exit_code 0 "myfunction arg1"

test_start "function_no_args"
assert_exit_code 1 "myfunction"
```

### Available assertions

| Function | Description |
|----------|-------------|
| `assert_equals expected actual [msg]` | Two values are equal |
| `assert_not_equals unexpected actual [msg]` | Two values differ |
| `assert_exit_code code command` | Command exits with given code |
| `assert_output_contains needle command` | Output contains string |
| `assert_output_not_contains needle command` | Output lacks string |
| `assert_output_matches pattern command` | Output matches regex |
| `assert_file_exists path [msg]` | File exists |
| `assert_file_not_exists path [msg]` | File doesn't exist |
| `assert_dir_exists path [msg]` | Directory exists |
| `assert_dir_not_exists path [msg]` | Directory doesn't exist |
| `assert_true condition [msg]` | Condition is true |
| `assert_false condition [msg]` | Condition is false |
| `assert_empty value [msg]` | String is empty |
| `assert_not_empty value [msg]` | String isn't empty |
| `assert_file_contains file needle [msg]` | File contains text |
| `assert_file_not_contains file needle [msg]` | File lacks text |

### Mock utilities

| Function | Description |
|----------|-------------|
| `mock_init` | Initialize mock environment |
| `mock_command name output [exit_code]` | Create a mock command |
| `mock_command_spy name [output] [exit_code]` | Create a mock that records calls |
| `mock_get_calls name` | Get spy call history |
| `mock_call_count name` | Get number of spy calls |
| `mock_file content [filename]` | Create temp file with content |
| `mock_dir [prefix]` | Create temp directory |
| `mock_archive type [content]` | Create a mock archive file |
| `mock_env var_name value` | Set an environment variable |
| `mock_cleanup` | Clean up all mocks |

## Test categories

### Unit tests (`tests/unit/`)

Test individual functions in isolation. Each file follows the `test_*.sh` naming convention and is discoverable with `ls tests/unit/`.

### Integration tests (`tests/integration/`)

Test complete workflows like the installation script and end-to-end apply behavior.

### Performance tests (`tests/performance/`)

Measure resource efficiency with shell startup benchmarks and load tests.

## Coverage goals

| Category | Target | Current |
|----------|--------|---------|
| Module coverage | >=95% | 100% |
| Unit test files | - | 425 |
| Integration test files | - | 11 |
| Total test files | - | 436 |
| Named tests (`test_start`) | - | 2149 |
| Unit test pass rate | 100% | 100% |

CI enforces module coverage via:

```bash
MIN_COVERAGE=95 ./tests/framework/module_coverage.sh
```

For a current local baseline, run:

```bash
bash ./scripts/qa/coverage-baseline.sh --with-module-coverage
```

## CI integration

Tests run automatically on every push to main, every pull request, and weekly scheduled runs (Monday 6 AM UTC).

### GitHub Actions example

```yaml
- name: Run Tests
  run: |
    chmod +x ./tests/framework/test_runner.sh
    ./tests/framework/test_runner.sh

- name: Run Integration Tests
  run: |
    RUN_INTEGRATION=1 ./tests/framework/test_runner.sh

- name: Run Performance Benchmarks
  run: |
    ./tests/performance/benchmark_runner.sh
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_INTEGRATION` | `0` | Set to `1` to include integration tests |
| `VERBOSE` | `0` | Set to `1` for verbose output |
| `REPO_ROOT` | Auto-detected | Repository root directory |
| `TESTS_DIR` | Auto-detected | Tests directory |

## Best practices

1. **Isolation** -- Each test should be independent and self-contained.
2. **Cleanup** -- Use mocks that auto-cleanup via traps.
3. **No sleep** -- Avoid `sleep` or hardcoded delays.
4. **Descriptive names** -- Test names should describe what's being verified.
5. **Edge cases** -- Test error conditions, not just happy paths.
6. **Security** -- Include tests for dangerous input rejection.

## Troubleshooting

### Tests not found

Make sure test files match the `test_*.sh` pattern and are executable:

```bash
chmod +x tests/unit/test_*.sh
chmod +x tests/integration/test_*.sh
```

### Function not available

If a test reports "function not available", verify the source file exists:

```bash
ls -la .chezmoitemplates/functions/
```

### Mock cleanup issues

If mocks aren't cleaning up, make sure you aren't running with `set -e` before mock operations that might intentionally fail.
