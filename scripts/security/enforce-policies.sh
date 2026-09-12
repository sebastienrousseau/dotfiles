#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/dot/ui.sh"
ui_init

# Logging function (also writes to log file)
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
  echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Per-check outcomes, recorded by main() and rendered by generate_report().
# Parallel arrays rather than an associative array: this runs under bash 3.2 on
# stock macOS, where `declare -A` does not exist.
CHECK_NAMES=()
CHECK_RESULTS=()

record_check() {
  CHECK_NAMES+=("$1")
  CHECK_RESULTS+=("$2")
}

# Error handling
error_exit() {
  log "ERROR" "$1"
  exit 1
}

# Check if required tools are installed.
#
# Only the tools every check needs are fatal. gitleaks, shellcheck and opa each
# back exactly one check, and treating them as fatal meant a machine without
# opa ran NO checks at all — as a pre-commit hook, that is a gate that silently
# does nothing on most contributors' machines. A missing optional tool now skips
# its own check and nothing else.
#
# A skip is never counted as a pass: it is reported as SKIPPED in the output and
# in the report, and DOTFILES_POLICY_STRICT=1 turns any skip into a hard error
# so CI can demand the full set.
MISSING_OPTIONAL=()

have_tool() {
  command -v "$1" >/dev/null 2>&1
}

check_dependencies() {
  log "INFO" "Checking dependencies..."

  local missing_required=()
  local tool

  for tool in grep find git; do
    have_tool "$tool" || missing_required+=("$tool")
  done

  if [[ ${#missing_required[@]} -gt 0 ]]; then
    error_exit "Missing required tools: ${missing_required[*]}"
  fi

  for tool in gitleaks shellcheck opa; do
    have_tool "$tool" || MISSING_OPTIONAL+=("$tool")
  done

  if [[ ${#MISSING_OPTIONAL[@]} -gt 0 ]]; then
    if [[ "${DOTFILES_POLICY_STRICT:-0}" == "1" ]]; then
      error_exit "Missing tools (strict mode): ${MISSING_OPTIONAL[*]}"
    fi
    log "WARN" "Not installed, related checks will be SKIPPED: ${MISSING_OPTIONAL[*]}"
  fi

  log "INFO" "Dependency check complete"
}

# Scan for hardcoded secrets
# repo_files [pattern] — NUL-separated list of TRACKED files.
#
# Every check below used to walk the working tree with `find`, which pulls in
# whatever happens to be sitting there: coverage/ alone is 165 MB of xtrace
# output and produced 50 of the 52 gitleaks findings on a clean checkout, and
# it is gitignored at .gitignore:80 with zero tracked files. A policy gate
# about the repository should examine the repository, so this asks git.
#
# Falls back to find when run outside a work tree (a tarball, say), with the
# same exclusions spelled out rather than assumed.
repo_files() {
  local pattern="${1:-}"
  if git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [[ -n "$pattern" ]]; then
      git -C "${REPO_ROOT}" ls-files -z -- "$pattern"
    else
      git -C "${REPO_ROOT}" ls-files -z
    fi
  else
    if [[ -n "$pattern" ]]; then
      find "${REPO_ROOT}" -name "$pattern" -type f \
        -not -path "*/.git/*" -not -path "*/coverage/*" -not -path "*/node_modules/*" -print0
    else
      find "${REPO_ROOT}" -type f \
        -not -path "*/.git/*" -not -path "*/coverage/*" -not -path "*/node_modules/*" -print0
    fi
  fi
}

scan_secrets() {
  log "INFO" "Scanning for hardcoded secrets..."

  local violations=0

  # gitleaks in GIT mode, not --no-git.
  #
  # --no-git scanned the working tree, which meant gitignored build output
  # (coverage/, 165 MB) and, worse, it cannot honour .gitleaksignore: those
  # entries are fingerprinted `<commit>:<file>:<rule>:<line>`, and with no
  # commit to key on, every allowlisted false positive came back. That is how
  # this reported "potential secrets" while `gitleaks detect` over all 2278
  # commits reported none.
  #
  # Git mode is also ~18x faster here: 10s against 3m0s.
  local gl_out
  if ! have_tool gitleaks; then
    log "WARN" "⏭  gitleaks SKIPPED (not installed) — pattern scan still runs"
  elif gl_out="$(gitleaks detect --source="${REPO_ROOT}" \
    --config="${REPO_ROOT}/config/gitleaks.toml" \
    --redact --no-banner 2>&1)"; then
    log "INFO" "✅ No secrets detected by gitleaks"
  else
    log "WARN" "❌ Potential secrets detected by gitleaks"
    printf '%s\n' "$gl_out" | grep -E '^(Finding|File|RuleID|Commit):' | head -40 >>"${LOG_FILE}" 2>/dev/null || true
    violations=$((violations + 1))
  fi

  # A short list of patterns that are unambiguous on sight, scanned over
  # TRACKED files only.
  #
  # The previous list could not pass on any real repository. `[0-9a-f]{32,}`
  # matches every git SHA, checksum and fingerprint in the tree, so it fired
  # unconditionally; and `key\s*=\s*"..."` matches documentation, test
  # fixtures and any config key whose name ends in "key". Four of the six
  # patterns reported a violation on a clean checkout, which trains a reader
  # to ignore the output — the opposite of what a gate is for.
  #
  # What survives is the shapes that do not occur by accident. Everything
  # else is gitleaks' job, and it does it with entropy analysis and an
  # allowlist rather than a bare grep.
  local secret_patterns=(
    'AKIA[0-9A-Z]{16}'                   # AWS access key id
    'ASIA[0-9A-Z]{16}'                   # AWS temporary access key id
    '-----BEGIN [A-Z ]*PRIVATE KEY-----' # any PEM private key block
    'xox[baprs]-[0-9A-Za-z-]{10,}'       # Slack token
    'ghp_[0-9A-Za-z]{36}'                # GitHub personal access token
    'AIza[0-9A-Za-z_-]{35}'              # Google API key
  )

  # Two kinds of file contain these shapes on purpose, and both already
  # declare it using gitleaks' own conventions rather than a list kept here:
  #
  #   * the gitleaks config itself — it allowlists a fake AWS key by value,
  #     so a rule-definition file necessarily holds the shape its rules
  #     match. (Deliberately not quoted here: writing the literal out made
  #     THIS file match its own pattern, which is the same self-match the
  #     original guarded against with --exclude=enforce-policies.sh);
  #   * fixtures that test secret detection — the atuin history filter's test
  #     carries `export AWS_SECRET_ACCESS_KEY=ASIA...  # gitleaks:allow`,
  #     because the point of the test is that such a line gets filtered.
  #
  # Honouring `gitleaks:allow` means one convention, already understood by
  # contributors and by gitleaks, instead of a second exclusion list here
  # that would drift out of step with the first.
  local pattern hits f line
  for pattern in "${secret_patterns[@]}"; do
    hits=""
    while IFS= read -r -d '' f; do
      case "$f" in
        config/gitleaks.toml | .gitleaks.toml) continue ;;
      esac
      [[ -f "${REPO_ROOT}/$f" ]] || continue
      while IFS= read -r line; do
        [[ "$line" == *"gitleaks:allow"* ]] && continue
        hits="${hits}${f}\n"
        break
      done < <(LC_ALL=C grep -E "${pattern}" "${REPO_ROOT}/$f" 2>/dev/null || true)
    done < <(repo_files)
    if [[ -n "$hits" ]]; then
      log "WARN" "❌ Credential pattern ${pattern} found in:"
      printf '%b' "$hits" | head -10 | while IFS= read -r h; do
        [[ -n "$h" ]] && log "WARN" "     ${h}"
      done
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

  # World-writable is the property worth catching. The old test was
  # `[[ $perms -gt 755 ]]`, comparing an octal mode as a decimal number,
  # which lets 764 (group-writable) through while flagging 775.
  # Paths are reported repository-relative, the way every other check reports
  # them, so the output is diffable between machines.
  #
  # Symlinks are skipped. A symlink carries its own mode bits, but the kernel
  # ignores them: access is governed entirely by the target, which is checked
  # on its own if it is tracked. Those bits are also not portable — Linux
  # creates symlinks 777 and macOS 755 — so including them made this pass on a
  # Mac and fail on a runner for the same eight tracked symlinks
  # (.gitleaks.toml, .pre-commit-config.yaml and friends, all pointing into
  # config/). `[[ -f ]]` follows the link, so it cannot filter them; -L must be
  # tested first.
  local file perms abs
  while IFS= read -r -d '' file; do
    abs="${REPO_ROOT}/${file}"
    [[ -L "$abs" ]] && continue
    [[ -f "$abs" ]] || continue
    perms=$(stat -c %a "$abs" 2>/dev/null || stat -f %OLp "$abs" 2>/dev/null) || continue
    # Other-writable is the bit that matters; group-writable in a repo is
    # normal on shared checkouts.
    if ((8#${perms} & 8#0002)); then
      log "WARN" "❌ World-writable file: ${file} (${perms})"
      violations=$((violations + 1))
    fi
  done < <(repo_files)

  # Executable text files. `find -executable` is GNU-only: on macOS, where
  # this hook actually runs for most contributors, that predicate is an
  # error and the whole loop found nothing. Test the file instead.
  # Symlinks skipped here for the same reason: `-x` follows the link, so a
  # tracked symlink pointing at any executable would be reported as an
  # executable text file.
  local ext
  for ext in md txt json yaml yml toml; do
    while IFS= read -r -d '' file; do
      [[ -L "${REPO_ROOT}/${file}" ]] && continue
      if [[ -x "${REPO_ROOT}/${file}" ]]; then
        log "WARN" "❌ Executable text file: ${file}"
        violations=$((violations + 1))
      fi
    done < <(repo_files "*.${ext}")
  done

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ File permissions are appropriate"
  fi

  return $violations
}

# Validate shell scripts
validate_shell_scripts() {
  log "INFO" "Validating shell scripts..."

  if ! have_tool shellcheck; then
    log "WARN" "⏭  Shell script validation SKIPPED (shellcheck not installed)"
    return 2
  fi

  local violations=0

  # Tracked scripts only, at the severity CI gates on. Running plain
  # `shellcheck` here contradicted tools/ci and the Shell Lint workflow,
  # which use `-S error` / `-S warning`, so this reported "violations" for
  # style notes that the repository has deliberately decided not to gate.
  local script
  while IFS= read -r -d '' script; do
    [[ -f "${REPO_ROOT}/${script}" ]] || continue
    if ! shellcheck -S error -x "${REPO_ROOT}/${script}" >/dev/null 2>&1; then
      log "WARN" "❌ ShellCheck errors in: ${script}"
      violations=$((violations + 1))
    fi
  done < <(repo_files "*.sh")

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ All shell scripts pass validation"
  fi

  return $violations
}

# check_environment_variables() was removed here.
#
# It warned when a file contained `^[A-Z_]+=...` but did not also contain
# `${VAR:-default}` ANYWHERE in the same file. That is not a security
# property: one defaulted variable anywhere exempted every assignment in the
# file, and a file with no defaults at all — a constants file, a .env
# template, a generated manifest — was flagged regardless of whether any
# value was sensitive. It ran `file` on every path in the working tree to
# decide what to read.
#
# There is no threshold that makes the condition meaningful, so it is gone
# rather than tuned. Hardcoded credentials are what gitleaks and the pattern
# list in scan_secrets() are for, and they judge the value rather than
# whether a neighbouring line happens to use parameter expansion.

# Validate OPA policies
validate_policies() {
  log "INFO" "Validating OPA policies..."

  if [[ ! -f "${POLICIES_DIR}/security.rego" ]]; then
    log "WARN" "❌ Security policy file not found"
    return 1
  fi

  if ! have_tool opa; then
    log "WARN" "⏭  OPA policy validation SKIPPED (opa not installed)"
    return 2
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

  # Tracked files only. A `.env` a contributor keeps locally, or a key in an
  # ignored scratch directory, is not something this repository ships — and
  # flagging it trains people to ignore the check. What matters is whether
  # such a file is committed.
  #
  # Each name is queried at the root AND at any depth. A git pathspec with a
  # wildcard (`*.key`) already matches at any depth, because `*` spans `/` in
  # pathspecs; a bare name (`id_rsa`, `.env`) matches ONLY at the repository
  # root. Without the `*/` form, a committed `.ssh/id_rsa` — the likeliest
  # place for a private key to appear — would not have been reported at all.
  local pattern file
  for pattern in "${sensitive_patterns[@]}"; do
    while IFS= read -r -d '' file; do
      if [[ ! "$file" =~ (environment-template\.env|\.pub$|KEYS\.asc$) ]]; then
        log "WARN" "❌ Sensitive file committed: ${file}"
        violations=$((violations + 1))
      fi
    done < <(
      repo_files "${pattern}"
      repo_files "*/${pattern}"
    )
  done

  if [[ $violations -eq 0 ]]; then
    log "INFO" "✅ No sensitive files detected"
  fi

  return $violations
}

# Render the checklist from what actually ran, so a failing check cannot show
# a tick. The previous version printed six fixed ✅ lines regardless of outcome,
# including one for a check that no longer exists.
_report_checklist() {
  local i
  # An empty array expansion is an unbound-variable error under `set -u` on
  # bash 3.2, so the guard is load-bearing, not defensive noise.
  [[ ${#CHECK_NAMES[@]} -eq 0 ]] && return 0
  for i in "${!CHECK_NAMES[@]}"; do
    if [[ "${CHECK_RESULTS[$i]}" == "SKIPPED" ]]; then
      echo "- ⏭ ${CHECK_NAMES[$i]} — SKIPPED (required tool not installed)"
    elif [[ "${CHECK_RESULTS[$i]}" == "0" ]]; then
      echo "- ✅ ${CHECK_NAMES[$i]}"
    else
      echo "- ❌ ${CHECK_NAMES[$i]} (${CHECK_RESULTS[$i]} violation(s))"
    fi
  done
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

$(_report_checklist)

## Security Score

$(if [[ $total_violations -eq 0 ]]; then echo "🟢 **PASSED** - No security violations detected"; else echo "🔴 **FAILED** - ${total_violations} violations detected"; fi)

## Recommendations

1. Review any flagged violations in the audit log
2. Ensure proper file permissions (644 for files, 755 for executables)
3. Keep secrets out of tracked files; use the environment template for configuration
4. Run this script regularly as part of your development workflow

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

  # Run all checks, recording each outcome for the report.
  local rc

  local label

  rc=0
  scan_secrets || rc=$?
  label="Secrets scanning (gitleaks + high-signal patterns)"
  have_tool gitleaks || label="Secrets scanning (pattern scan only, gitleaks absent)"
  record_check "$label" "$rc"
  total_violations=$((total_violations + rc))

  rc=0
  check_file_permissions || rc=$?
  record_check "File permissions validation" "$rc"
  total_violations=$((total_violations + rc))

  # rc 2 is the skip sentinel: the tool that backs this check is absent. A skip
  # adds nothing to the violation count and is rendered as SKIPPED, never as a
  # tick — use DOTFILES_POLICY_STRICT=1 to make it an error instead.
  rc=0
  validate_shell_scripts || rc=$?
  if have_tool shellcheck; then
    record_check "Shell script analysis (shellcheck)" "$rc"
    total_violations=$((total_violations + rc))
  else
    record_check "Shell script analysis (shellcheck)" "SKIPPED"
  fi

  rc=0
  validate_policies || rc=$?
  if have_tool opa; then
    [[ $rc -ne 0 ]] && rc=1
    record_check "OPA policy validation" "$rc"
    total_violations=$((total_violations + rc))
  else
    record_check "OPA policy validation" "SKIPPED"
  fi

  rc=0
  check_sensitive_files || rc=$?
  record_check "Sensitive files detection" "$rc"
  total_violations=$((total_violations + rc))

  # Generate report
  generate_report "$total_violations"

  # Final result
  if [[ $total_violations -eq 0 ]]; then
    ui_ok "All security checks passed"
    log "INFO" "Security policy enforcement completed successfully"
    exit 0
  else
    ui_err "$total_violations violations" "Security policy enforcement failed"
    ui_warn "Details" "Check ${LOG_FILE}"
    ui_warn "Report" "Review security-report.md"
    log "ERROR" "Security policy enforcement failed with ${total_violations} violations"
    exit 1
  fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
