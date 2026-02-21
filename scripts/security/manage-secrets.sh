#!/usr/bin/env bash
## Secure Configuration Management.
##
## Manages environment variables and secrets across local development.
## Provides init, validate, rotate, and audit capabilities for credentials.
##
## # Usage
## manage-secrets.sh init           # Create .env.local from template
## manage-secrets.sh validate       # Check configuration integrity
## manage-secrets.sh check          # Scan for hardcoded secrets
## manage-secrets.sh rotate github  # Secret rotation guide
## manage-secrets.sh clean          # Remove temporary files
##
## # Dependencies
## - stat: Permission checking
## - grep: Pattern matching
## - find: File discovery
##
## # Platform Notes
## - macOS: Uses BSD stat syntax
## - Linux: Uses GNU stat syntax
## - WSL: Works with Linux filesystem permissions
##
## # Security
## - Creates .env.local with 600 permissions
## - Automatically adds .env.local to .gitignore
## - Never commits secrets to version control
##
## # Idempotency
## Safe to run repeatedly. init requires --force to overwrite.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
readonly ENV_TEMPLATE="${REPO_ROOT}/.github/security-policies/environment-template.env"
readonly ENV_LOCAL="${REPO_ROOT}/.env.local"

# Color codes (respect NO_COLOR: https://no-color.org)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Help text
show_help() {
  cat <<EOF
Secure Configuration Management

USAGE:
    $0 <command> [options]

COMMANDS:
    init        Initialize secure environment configuration
    validate    Validate environment variables and security
    template    Show environment variable template
    check       Check for hardcoded secrets
    rotate      Help rotate secrets and tokens
    clean       Clean temporary files and logs

OPTIONS:
    -h, --help     Show this help message
    -v, --verbose  Verbose output
    -f, --force    Force operations (use with caution)

EXAMPLES:
    $0 init                 # Initialize .env.local from template
    $0 validate             # Validate current configuration
    $0 check                # Scan for hardcoded secrets
    $0 rotate github        # Guide for rotating GitHub tokens
    $0 clean                # Clean up temporary files

SECURITY NOTES:
    - Never commit .env.local to version control
    - Use different tokens for different environments
    - Rotate secrets regularly (every 90 days)
    - Use least-privilege principle
EOF
}

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Initialize environment configuration
init_config() {
  local force_init=false
  if [[ "${1:-}" == "--force" ]]; then
    force_init=true
  fi

  log_info "Initializing secure environment configuration..."

  if [[ -f "$ENV_LOCAL" ]] && [[ "$force_init" == "false" ]]; then
    log_warning ".env.local already exists"
    echo "Use --force to overwrite, or edit the existing file manually"
    return 1
  fi

  if [[ ! -f "$ENV_TEMPLATE" ]]; then
    log_error "Environment template not found: $ENV_TEMPLATE"
    return 1
  fi

  # Copy template
  cp "$ENV_TEMPLATE" "$ENV_LOCAL"

  # Set secure permissions
  chmod 600 "$ENV_LOCAL"

  log_success ".env.local created from template"
  log_info "Next steps:"
  echo "  1. Edit .env.local and configure required variables"
  echo "  2. Run '$0 validate' to check configuration"
  echo "  3. Source the file: source .env.local"

  # Add to .gitignore if not present
  if [[ -f "${REPO_ROOT}/.gitignore" ]]; then
    if ! grep -q "\.env\.local" "${REPO_ROOT}/.gitignore"; then
      echo ".env.local" >>"${REPO_ROOT}/.gitignore"
      log_info "Added .env.local to .gitignore"
    fi
  fi
}

# Validate environment configuration
validate_config() {
  log_info "Validating environment configuration..."

  local issues=0

  # Check if .env.local exists
  if [[ ! -f "$ENV_LOCAL" ]]; then
    log_error ".env.local not found. Run '$0 init' to create it."
    return 1
  fi

  # Check file permissions
  local perms
  perms=$(stat -c %a "$ENV_LOCAL" 2>/dev/null || stat -f %A "$ENV_LOCAL")
  if [[ "$perms" != "600" ]]; then
    log_warning ".env.local has incorrect permissions ($perms). Should be 600."
    log_info "Fix with: chmod 600 $ENV_LOCAL"
    issues=$((issues + 1))
  fi

  # Source and validate environment
  # shellcheck source=/dev/null
  if source "$ENV_LOCAL" 2>/dev/null; then
    log_success ".env.local loads successfully"
  else
    log_error ".env.local has syntax errors"
    issues=$((issues + 1))
  fi

  # Check for required variables
  local required_vars=("GITHUB_TOKEN")

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      log_warning "Required variable $var is not set or empty"
      issues=$((issues + 1))
    else
      log_success "$var is configured"
    fi
  done

  # Check for security patterns
  if grep -E '(password|secret|key|token)="[^"]{1,}"' "$ENV_LOCAL" >/dev/null 2>&1; then
    log_warning "Found configured credentials (this is expected)"
  fi

  if [[ $issues -eq 0 ]]; then
    log_success "Environment configuration is valid"
    return 0
  else
    log_error "Found $issues configuration issues"
    return 1
  fi
}

# Show template
show_template() {
  if [[ -f "$ENV_TEMPLATE" ]]; then
    log_info "Environment variable template:"
    echo "----------------------------------------"
    cat "$ENV_TEMPLATE"
  else
    log_error "Template file not found: $ENV_TEMPLATE"
    return 1
  fi
}

# Check for hardcoded secrets
check_secrets() {
  log_info "Scanning for hardcoded secrets..."

  local violations=0

  # Define patterns to search for
  local patterns=(
    'password\s*=\s*["\047][^"\047]*["\047]'
    'token\s*=\s*["\047][^"\047]*["\047]'
    'secret\s*=\s*["\047][^"\047]*["\047]'
    'key\s*=\s*["\047][^"\047]*["\047]'
    'AKIA[0-9A-Z]{16}'     # AWS Access Key
    'ghp_[A-Za-z0-9_]{36}' # GitHub Personal Access Token
    '[0-9a-f]{32,64}'      # Potential hash/token
  )

  # Search in specific file types
  local file_patterns=("*.sh" "*.yml" "*.yaml" "*.toml" "*.json" "*.tmpl")

  for file_pattern in "${file_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      # Skip the security management files themselves
      if [[ "$file" =~ (environment-template\.env|manage-secrets\.sh|\.env\.local) ]]; then
        continue
      fi

      for pattern in "${patterns[@]}"; do
        if grep -H -n -E -i "$pattern" "$file" 2>/dev/null; then
          log_warning "Potential secret in $file"
          violations=$((violations + 1))
        fi
      done
    done < <(find "$REPO_ROOT" -name "$file_pattern" -not -path "*/.git/*" -print0)
  done

  if [[ $violations -eq 0 ]]; then
    log_success "No hardcoded secrets detected"
  else
    log_error "Found $violations potential hardcoded secrets"
    log_info "Review the output above and replace with environment variables"
  fi

  return $violations
}

# Guide for rotating secrets
rotate_secrets() {
  local service="${1:-}"

  if [[ -z "$service" ]]; then
    log_info "Available rotation guides:"
    echo "  github    - GitHub Personal Access Tokens"
    echo "  aws       - AWS Access Keys"
    echo "  gcp       - GCP Service Account Keys"
    echo "  ssh       - SSH Keys"
    echo ""
    echo "Usage: $0 rotate <service>"
    return 0
  fi

  case "$service" in
    "github")
      cat <<'EOF'
GitHub Token Rotation Guide:

1. Create new Personal Access Token:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Set expiration (90 days recommended)
   - Select minimal required scopes:
     • repo (for private repos)
     • workflow (for GitHub Actions)

2. Update environment:
   - Edit .env.local
   - Replace GITHUB_TOKEN value
   - Test with: gh auth status

3. Update CI/CD:
   - Go to repository Settings → Secrets and variables → Actions
   - Update GITHUB_TOKEN secret

4. Revoke old token:
   - Go back to https://github.com/settings/tokens
   - Find old token and click "Delete"

5. Verify:
   - Run: scripts/security/manage-secrets.sh validate
   - Test repository operations
EOF
      ;;
    "aws")
      cat <<'EOF'
AWS Access Key Rotation Guide:

1. Create new access key:
   - AWS Console → IAM → Users → [Your User] → Security credentials
   - Click "Create access key"
   - Download credentials

2. Update environment:
   - Edit .env.local
   - Update AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
   - Test with: aws sts get-caller-identity

3. Update CI/CD:
   - Update secrets in GitHub repository
   - Test AWS operations in pipeline

4. Deactivate old key:
   - In AWS Console, set old key status to "Inactive"
   - Wait 24-48 hours, monitor for issues
   - Delete old key if no issues

5. Security best practices:
   - Use IAM roles where possible
   - Implement least privilege access
   - Enable CloudTrail logging
EOF
      ;;
    "ssh")
      cat <<'EOF'
SSH Key Rotation Guide:

1. Generate new SSH key:
   - Run: ssh-keygen -t ed25519 -C "your_email@example.com"
   - Save to new file: ~/.ssh/id_ed25519_new

2. Add to SSH agent:
   - Run: ssh-add ~/.ssh/id_ed25519_new

3. Update remote services:
   - GitHub: Settings → SSH and GPG keys → Add new key
   - Servers: Add to ~/.ssh/authorized_keys

4. Update local config:
   - Edit ~/.ssh/config
   - Update IdentityFile paths

5. Test connections:
   - ssh -T git@github.com
   - Test server connections

6. Remove old keys:
   - Remove from remote authorized_keys
   - Remove from local ~/.ssh/
   - Remove from SSH agent
EOF
      ;;
    *)
      log_error "Unknown service: $service"
      log_info "Available services: github, aws, gcp, ssh"
      return 1
      ;;
  esac
}

# Clean temporary files
clean_files() {
  log_info "Cleaning temporary files and logs..."

  local files_to_clean=(
    "${REPO_ROOT}/.security-audit.log"
    "${REPO_ROOT}/security-report.md"
    "${REPO_ROOT}/trivy-results.sarif"
    "${REPO_ROOT}/grype-results.sarif"
    "${REPO_ROOT}/checkov-results.sarif"
    "${REPO_ROOT}/shellcheck-results.sarif"
    "${REPO_ROOT}/container-scan.sarif"
    "${REPO_ROOT}/security-attestation.json"
  )

  local cleaned=0
  for file in "${files_to_clean[@]}"; do
    if [[ -f "$file" ]]; then
      rm "$file"
      log_success "Removed $file"
      cleaned=$((cleaned + 1))
    fi
  done

  if [[ $cleaned -eq 0 ]]; then
    log_info "No temporary files to clean"
  else
    log_success "Cleaned $cleaned temporary files"
  fi
}

# Main function
main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    "init")
      init_config "$@"
      ;;
    "validate")
      validate_config
      ;;
    "template")
      show_template
      ;;
    "check")
      check_secrets
      ;;
    "rotate")
      rotate_secrets "$@"
      ;;
    "clean")
      clean_files
      ;;
    "-h" | "--help" | "help" | "")
      show_help
      ;;
    *)
      log_error "Unknown command: $command"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
