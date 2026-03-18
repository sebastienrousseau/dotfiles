#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

./tests/framework/test_runner.sh utility_functions
