#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

MIN_COVERAGE="${MIN_COVERAGE:-100}" ./tests/framework/module_coverage.sh
