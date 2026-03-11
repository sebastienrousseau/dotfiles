#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test dotfiles README instructions across all environments using Docker
# Usage: ./tests/test-docker.sh [target...]
# Examples:
#   ./tests/test-docker.sh              # Run all tests
#   ./tests/test-docker.sh ubuntu-test  # Run only Ubuntu test
#   ./tests/test-docker.sh arch-test    # Run only Arch test

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGETS=(ubuntu-test debian-test arch-test ubuntu-eza-test)
PASSED=0
FAILED=0
FAILURES=()

# Use specified targets or all
if [ $# -gt 0 ]; then
  TARGETS=("$@")
fi

printf '%b\n' "${BLUE}${BOLD}Testing dotfiles across ${#TARGETS[@]} environment(s)${NC}"
echo ""

for target in "${TARGETS[@]}"; do
  printf '%b\n' "${BLUE}==> Building: ${BOLD}${target}${NC}"
  if docker build --target "$target" -f Dockerfile.test -t "dotfiles-test:${target}" . 2>&1; then
    printf '%b\n' "${GREEN}==> PASSED: ${target}${NC}"
    PASSED=$((PASSED + 1))
  else
    printf '%b\n' "${RED}==> FAILED: ${target}${NC}"
    FAILED=$((FAILED + 1))
    FAILURES+=("$target")
  fi
  echo ""
done

printf '%b\n' "${BOLD}Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC} (${#TARGETS[@]} total)"

if [ ${FAILED} -gt 0 ]; then
  printf '%b\n' "${RED}Failed targets: ${FAILURES[*]}${NC}"
  exit 1
fi
