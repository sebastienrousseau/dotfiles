#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Test runner: %s\n' "$repo_root/tests/framework/test_runner.sh"
printf 'Run all tests: ./tests/framework/test_runner.sh\n'
printf 'Run matching tests: ./tests/framework/test_runner.sh utility_functions\n'
printf 'Run integration tests: RUN_INTEGRATION=1 ./tests/framework/test_runner.sh -i\n'
