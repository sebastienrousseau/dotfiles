#!/usr/bin/env bash
# Security Policy Enforcement Script
# This script enforces security policies across the dotfiles repository

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
readonly POLICIES_DIR="${REPO_ROOT}/.github/security-policies"
readonly LOG_FILE="${REPO_ROOT}/.security-audit.log"

# Color codes for output (respect NO_COLOR: https://no-color.org)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly NC='\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' NC=''
fi

# Logging function
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

  echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
  log "ERROR" "$1"
  exit 1
}

# Check if required tools are installed
check_dependencies() {
  log "INFO" "Checking dependencies..."

  local missing_tools=()

  # Required tools
  local tools=("opa" "gitleaks" "shellcheck" "grep" "find")

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    error_exit "Missing required tools: ${missing_tools[*]}"
  fi

  log "INFO" "All dependencies satisfied"
}

# Scan for hardcoded secrets
scan_secrets() {
  log "INFO" "Scanning for hardcoded secrets..."

  local violations=0

  # Run gitleaks
  if gitleaks detect --source="${REPO_ROOT}" --config="${REPO_ROOT}/config/gitleaks.toml" --no-git >/dev/null 2>&1; then
    log "INFO" "✅ No secrets detected by gitleaks"
  else
    log "WARN" "❌ Potential secrets detected by gitleaks"
    violations=$((violations + 1))
  fi

  # Manual pattern checks
  local secret_patterns=(
    'password\s*=\s*["\047][^"\047]*["\047]'
    'token\s*=\s*["\047][^"\047]*["\047]'
    'secret\s*=\s*["\047][^"\047]*["\047]'
    'key\s*=\s*["\047][^"\047]*["\047]'
    'AKIA[0-9A-Z]{16}' # AWS Access Key
    '[0-9a-f]{32,}'    # Potential hash/token
  )

  for pattern in "${secret_patterns[@]}"; do
    if grep -r -E -i "${pattern}" "${REPO_ROOT}" \
      --exclude-dir=".git" \
      --exclude="*.log" \
      --exclude="enforce-policies.sh" \
      --exclude="environment-template.env" >/dev/null 2>&1; then
      log "WARN" "❌ Potential hardcoded credential pattern found: ${pattern}"
      violations=$((violations + 1))
    fi
  done

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ No hardcoded secrets detected"
  fi

  return $violations
}

# Check file permissions
check_file_permissions() {
  log "INFO" "Checking file permissions..."

  local violations=0

  # Check for overly permissive files
  while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
      local perms
      perms=$(stat -c %a "$file" 2>/dev/null || stat -f %A "$file")
      if [[ $perms -gt 755 ]]; then
        log "WARN" "❌ Overly permissive file: ${file} (${perms})"
        violations=$((violations + 1))
      fi
    fi
  done < <(find "${REPO_ROOT}" -type f -not -path "*/.git/*" -print0)

  # Check for executable text files
  local text_extensions=("md" "txt" "json" "yaml" "yml" "toml")

  for ext in "${text_extensions[@]}"; do
    while IFS= read -r -d '' file; do
      if [[ -x "$file" ]]; then
        log "WARN" "❌ Executable text file: ${file}"
        violations=$((violations + 1))
      fi
    done < <(find "${REPO_ROOT}" -name "*.${ext}" -executable -not -path "*/.git/*" -print0)
  done

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ File permissions are appropriate"
  fi

  return $violations
}

# Validate shell scripts
validate_shell_scripts() {
  log "INFO" "Validating shell scripts..."

  local violations=0

  while IFS= read -r -d '' script; do
    if ! shellcheck "$script" >/dev/null 2>&1; then
      log "WARN" "❌ ShellCheck violations in: ${script}"
      violations=$((violations + 1))
    fi
  done < <(find "${REPO_ROOT}" -name "*.sh" -not -path "*/.git/*" -print0)

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ All shell scripts pass validation"
  fi

  return $violations
}

# Check environment variable usage
check_environment_variables() {
  log "INFO" "Checking environment variable usage..."

  local violations=0

  # Look for unprotected variable assignments
  while IFS= read -r -d '' file; do
    # Skip binary files and specific files
    if file "$file" | grep -q "text" && [[ ! "$file" =~ \.(log|env)$ ]]; then
      # Check for variables that should use default patterns
      if grep -E '^[A-Z_]+=.+$' "$file" >/dev/null 2>&1; then
        # Check if they use proper defaulting
        if ! grep -E '\$\{[A-Z_]+:-[^}]*\}' "$file" >/dev/null 2>&1; then
          local suspicious_vars
          suspicious_vars=$(grep -E '^[A-Z_]+=.+$' "$file" | head -3)
          if [[ -n "$suspicious_vars" ]]; then
            log "WARN" "❌ Potential hardcoded variables in ${file}: ${suspicious_vars}"
            violations=$((violations + 1))
          fi
        fi
      fi
    fi
  done < <(find "${REPO_ROOT}" -type f -not -path "*/.git/*" -not -path "*/.github/security-policies/*" -print0)

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ Environment variable usage is appropriate"
  fi

  return $violations
}

# Validate OPA policies
validate_policies() {
  log "INFO" "Validating OPA policies..."

  if [[ ! -f "${POLICIES_DIR}/security.rego" ]]; then
    log "WARN" "❌ Security policy file not found"
    return 1
  fi

  if opa test "${POLICIES_DIR}" >/dev/null 2>&1; then
    log "INFO" "✅ OPA policies are valid"
    return 0
  else
    log "WARN" "❌ OPA policy validation failed"
    return 1
  fi
}

# Check for sensitive files
check_sensitive_files() {
  log "INFO" "Checking for sensitive files..."

  local violations=0
  local sensitive_patterns=(
    "*.key"
    "*.pem"
    "*.p12"
    "*.pfx"
    "*.jks"
    "*.keystore"
    ".env"
    ".env.*"
    "credentials.json"
    "service-account.json"
    "id_rsa"
    "id_dsa"
    "id_ecdsa"
    "id_ed25519"
  )

  for pattern in "${sensitive_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      # Skip allowed files
      if [[ ! "$file" =~ (environment-template\.env|\.pub$) ]]; then
        log "WARN" "❌ Sensitive file detected: ${file}"
        violations=$((violations + 1))
      fi
    done < <(find "${REPO_ROOT}" -name "${pattern}" -not -path "*/.git/*" -print0)
  done

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ No sensitive files detected"
  fi

  return $violations
}

# Generate security report
generate_report() {
  local total_violations="$1"
  local report_file="${REPO_ROOT}/security-report.md"

  log "INFO" "Generating security report..."

  cat >"${report_file}" <<EOF
# Security Policy Enforcement Report

**Generated:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')
**Repository:** $(basename "${REPO_ROOT}")
**Total Violations:** ${total_violations}

## Security Checks Performed

- ✅ Secrets scanning (gitleaks + manual patterns)
- ✅ File permissions validation
- ✅ Shell script analysis (shellcheck)
- ✅ Environment variable usage check
- ✅ OPA policy validation
- ✅ Sensitive files detection

## Security Score

$(if [[ $total_violations -eq 0 ]]; then echo "🟢 **PASSED** - No security violations detected"; else echo "🔴 **FAILED** - ${total_violations} violations detected"; fi)

## Recommendations

1. Review any flagged violations in the audit log
2. Update hardcoded values to use environment variables
3. Ensure proper file permissions (644 for files, 755 for executables)
4. Use the provided environment template for configuration
5. Run this script regularly as part of your development workflow

## Next Steps

- Fix any identified violations
- Run \`scripts/security/enforce-policies.sh\` again to verify fixes
- Consider setting up automated policy enforcement in CI/CD

---
*This report was generated by the automated security policy enforcement system.*
EOF

  log "INFO" "Security report generated: ${report_file}"
}

# Main execution
main() {
  log "INFO" "Starting security policy enforcement..."

  # Initialize log file
  echo "# Security Audit Log - $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >"${LOG_FILE}"

  check_dependencies

  local total_violations=0

  # Run all checks
  scan_secrets || total_violations=$((total_violations + $?))
  check_file_permissions || total_violations=$((total_violations + $?))
  validate_shell_scripts || total_violations=$((total_violations + $?))
  check_environment_variables || total_violations=$((total_violations + $?))
  validate_policies || total_violations=$((total_violations + 1))
  check_sensitive_files || total_violations=$((total_violations + $?))

  # Generate report
  generate_report "$total_violations"

  # Final result
  if [[ $total_violations -eq 0 ]]; then
    echo -e "${GREEN}✅ All security checks passed!${NC}"
    log "INFO" "Security policy enforcement completed successfully"
    exit 0
  else
    echo -e "${RED}❌ Security policy enforcement failed with ${total_violations} violations${NC}"
    echo -e "${YELLOW}📋 Check ${LOG_FILE} for details${NC}"
    echo -e "${YELLOW}📋 Review security-report.md for summary${NC}"
    log "ERROR" "Security policy enforcement failed with ${total_violations} violations"
    exit 1
  fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
