#!/usr/bin/env bash
# CI Configuration Validation Script
# Verifies that all zero-warning policy components are properly configured

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}      CI CONFIGURATION VALIDATOR      ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Helper functions
check_file_exists() {
  local file="$1"
  local description="$2"

  if [[ -f "$file" ]]; then
    echo -e "  ${GREEN}✓${NC} $description"
    return 0
  else
    echo -e "  ${RED}✗${NC} $description"
    ((ERRORS++))
    return 1
  fi
}

check_pattern_in_file() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    echo -e "  ${GREEN}✓${NC} $description"
    return 0
  else
    echo -e "  ${RED}✗${NC} $description"
    ((ERRORS++))
    return 1
  fi
}

warn_if_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    echo -e "  ${YELLOW}⚠${NC} $description"
    ((WARNINGS++))
    return 1
  else
    echo -e "  ${GREEN}✓${NC} $description"
    return 0
  fi
}

# Check 1: Core CI files exist
echo -e "${BLUE}1. Core CI Files${NC}"
check_file_exists "$REPO_ROOT/.github/workflows/ci.yml" "Main CI workflow exists"
check_file_exists "$REPO_ROOT/.github/workflows/nightly.yml" "Nightly workflow exists"
check_file_exists "$REPO_ROOT/.github/workflows/security-enhanced.yml" "Security workflow exists"
check_file_exists "$REPO_ROOT/config/pre-commit-config.yaml" "Pre-commit configuration exists"
echo ""

# Check 2: Zero-warning enforcement
echo -e "${BLUE}2. Zero-Warning Policy Enforcement${NC}"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "zero-warning" "Zero-warning policy documented"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "fail on unformatted code" "Formatter failure enforced"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "warnings-as-errors" "Warnings treated as errors"

# Verify no || true patterns in security steps
warn_if_pattern "$REPO_ROOT/.github/workflows/ci.yml" "gitleaks.*||.*true" "Gitleaks bypass detected"
warn_if_pattern "$REPO_ROOT/.github/workflows/ci.yml" "shellcheck.*||.*true" "Shellcheck bypass detected"
echo ""

# Check 3: Test coverage requirements
echo -e "${BLUE}3. Test Coverage Requirements${NC}"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "100%" "100% coverage requirement"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "fail-under" "Coverage threshold enforcement"

if [[ -f "$REPO_ROOT/scripts/tests/framework/test_runner.sh" ]]; then
  echo -e "  ${GREEN}✓${NC} Test framework exists"
else
  echo -e "  ${RED}✗${NC} Test framework missing"
  ((ERRORS++))
fi
echo ""

# Check 4: Security scanning
echo -e "${BLUE}4. Security Scanning Configuration${NC}"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "security-secrets" "Secret scanning enabled"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "security-dependencies" "Dependency audit enabled"
check_pattern_in_file "$REPO_ROOT/config/pre-commit-config.yaml" "gitleaks" "Pre-commit secret scanning"
check_pattern_in_file "$REPO_ROOT/config/pre-commit-config.yaml" "detect-secrets" "Advanced secret detection"

# Verify no piped execution patterns
warn_if_pattern "$REPO_ROOT/.github/workflows/ci.yml" "curl.*|.*sh" "Dangerous piped execution"
warn_if_pattern "$REPO_ROOT/.github/workflows/ci.yml" "wget.*|.*bash" "Dangerous piped execution"
echo ""

# Check 5: Performance monitoring
echo -e "${BLUE}5. Performance Monitoring${NC}"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "benchmark" "Performance benchmarking enabled"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "500ms" "Shell startup threshold defined"
check_pattern_in_file "$REPO_ROOT/.github/workflows/nightly.yml" "performance-tracking" "Nightly performance tracking"
echo ""

# Check 6: Multi-OS support
echo -e "${BLUE}6. Multi-OS Testing${NC}"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "ubuntu-latest" "Linux testing enabled"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "macos-latest" "macOS testing enabled"
check_pattern_in_file "$REPO_ROOT/.github/workflows/nightly.yml" "matrix:" "OS matrix testing configured"
echo ""

# Check 7: Timeouts and efficiency
echo -e "${BLUE}7. Timeout and Efficiency Settings${NC}"
if grep -q "timeout-minutes: [0-9]" "$REPO_ROOT/.github/workflows/ci.yml"; then
  MAX_TIMEOUT=$(grep "timeout-minutes:" "$REPO_ROOT/.github/workflows/ci.yml" | \
    awk '{print $2}' | sort -n | tail -1)
  if [[ $MAX_TIMEOUT -le 15 ]]; then
    echo -e "  ${GREEN}✓${NC} Job timeouts properly configured (max: ${MAX_TIMEOUT}min)"
  else
    echo -e "  ${YELLOW}⚠${NC} Some jobs have long timeouts (max: ${MAX_TIMEOUT}min)"
    ((WARNINGS++))
  fi
else
  echo -e "  ${RED}✗${NC} No timeout configuration found"
  ((ERRORS++))
fi

check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "cache" "Dependency caching enabled"
echo ""

# Check 8: Branch protection readiness
echo -e "${BLUE}8. Branch Protection Readiness${NC}"
check_file_exists "$REPO_ROOT/.github/BRANCH_PROTECTION.md" "Branch protection documentation"
check_pattern_in_file "$REPO_ROOT/.github/workflows/ci.yml" "quality-gate" "Quality gate job defined"

# Check for required status check names
REQUIRED_CHECKS=(
  "lint-shell"
  "security-secrets"
  "security-dependencies"
  "test-unit"
  "quality-gate"
)

for check in "${REQUIRED_CHECKS[@]}"; do
  if grep -q "name:.*$check" "$REPO_ROOT/.github/workflows/ci.yml"; then
    echo -e "  ${GREEN}✓${NC} Required check '$check' defined"
  else
    echo -e "  ${RED}✗${NC} Required check '$check' missing"
    ((ERRORS++))
  fi
done
echo ""

# Check 9: Nightly extended testing
echo -e "${BLUE}9. Nightly Extended Testing${NC}"
if [[ -f "$REPO_ROOT/.github/workflows/nightly.yml" ]]; then
  check_pattern_in_file "$REPO_ROOT/.github/workflows/nightly.yml" "dependency-updates" "Dependency monitoring"
  check_pattern_in_file "$REPO_ROOT/.github/workflows/nightly.yml" "beta-tools-test" "Beta tool testing"
  check_pattern_in_file "$REPO_ROOT/.github/workflows/nightly.yml" "security-extended" "Extended security scanning"
  check_pattern_in_file "$REPO_ROOT/.github/workflows/nightly.yml" "cron:" "Scheduled execution"
else
  echo -e "  ${RED}✗${NC} Nightly workflow missing"
  ((ERRORS++))
fi
echo ""

# Final summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}           VALIDATION SUMMARY         ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}✅ PERFECT: CI configuration fully compliant${NC}"
  echo "   - Zero-warning policy properly enforced"
  echo "   - All security gates configured"
  echo "   - Performance monitoring active"
  echo "   - Ready for branch protection"
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "${YELLOW}⚠️  GOOD: CI mostly compliant with $WARNINGS warning(s)${NC}"
  echo "   - Core functionality working"
  echo "   - Minor improvements recommended"
else
  echo -e "${RED}❌ ISSUES: CI configuration has $ERRORS error(s) and $WARNINGS warning(s)${NC}"
  echo "   - Critical fixes required before deployment"
fi

echo ""
echo "Configuration Details:"
echo "  - Repository: $REPO_ROOT"
echo "  - Main CI: .github/workflows/ci.yml"
echo "  - Nightly: .github/workflows/nightly.yml"
echo "  - Pre-commit: config/pre-commit-config.yaml"
echo ""
echo "Next Steps:"
if [[ $ERRORS -gt 0 ]]; then
  echo "  1. Fix critical errors listed above"
  echo "  2. Re-run validation: $0"
fi
if [[ $WARNINGS -gt 0 ]]; then
  echo "  3. Address warnings for optimal configuration"
fi
echo "  4. Configure branch protection rules per BRANCH_PROTECTION.md"
echo "  5. Test CI pipeline with a small PR"

exit $ERRORS