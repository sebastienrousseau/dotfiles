#!/usr/bin/env bash
# Test dotfiles README instructions across all environments using Docker
# Usage: ./test-docker.sh [target...]
# Examples:
#   ./test-docker.sh              # Run all tests
#   ./test-docker.sh ubuntu-test  # Run only Ubuntu test
#   ./test-docker.sh arch-test    # Run only Arch test

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

echo -e "${BLUE}${BOLD}Testing dotfiles across ${#TARGETS[@]} environment(s)${NC}"
echo ""

for target in "${TARGETS[@]}"; do
  echo -e "${BLUE}==> Building: ${BOLD}${target}${NC}"
  if docker build --target "$target" -f Dockerfile.test -t "dotfiles-test:${target}" . 2>&1; then
    echo -e "${GREEN}==> PASSED: ${target}${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}==> FAILED: ${target}${NC}"
    FAILED=$((FAILED + 1))
    FAILURES+=("$target")
  fi
  echo ""
done

echo -e "${BOLD}Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC} (${#TARGETS[@]} total)"

if [ ${FAILED} -gt 0 ]; then
  echo -e "${RED}Failed targets: ${FAILURES[*]}${NC}"
  exit 1
fi
