# Security Documentation

**Dotfiles v0.2.471 - Product Hardening Release**

## Overview

This document describes the security features, hardening measures, and best practices implemented in Dotfiles v0.2.471.

## Table of Contents

1. [Security Modules](#security-modules)
2. [Features](#features)
3. [Best Practices](#best-practices)
4. [Verification](#verification)
5. [Audit Trail](#audit-trail)
6. [Testing](#testing)
7. [Reporting Issues](#reporting-issues)

---

## Security Modules

Dotfiles includes four core security modules designed to protect your shell environment:

### 1. Security Module (`lib/security.sh`)

Provides core security hardening utilities.

**Key Functions:**
- `harden_file_permissions()` - Verify and fix file permissions
- `harden_directory_permissions()` - Verify and fix directory permissions
- `verify_script_syntax()` - Check bash script syntax without execution
- `verify_script_quality()` - Run shellcheck validation
- `check_sensitive_file_perms()` - Audit sensitive files (.ssh, .aws, etc.)
- `check_for_secrets()` - Detect hardcoded secrets
- `verify_umask()` - Ensure secure umask settings
- `run_all_security_checks()` - Run comprehensive security audit

**Usage:**
```bash
source "$DOTFILES_DIR/lib/security.sh"

# Check all security issues
run_all_security_checks

# Check specific aspect
check_sensitive_file_perms
verify_umask
```

### 2. Validation Module (`lib/validation.sh`)

Comprehensive input validation and sanitization.

**Key Functions:**
- `validate_not_empty()` - Ensure value is not empty
- `validate_pattern()` - Match against regex pattern
- `validate_length()` - Check string length bounds
- `validate_alphanumeric()` - Accept only letters and numbers
- `validate_identifier()` - Validate variable names
- `validate_path()` - Prevent path traversal
- `validate_filename()` - Secure filename validation
- `validate_integer()` / `validate_positive_integer()` - Numeric validation
- `validate_email()` - Email format validation
- `validate_url()` - URL validation
- `validate_ipv4()` - IPv4 address validation
- `validate_readable_file()` - Check file exists and is readable
- `validate_readable_directory()` - Check directory exists and is readable
- `validate_command_exists()` - Verify command in PATH
- `sanitize_filename()` - Remove unsafe characters from filenames
- `sanitize_varname()` - Convert to safe variable names

**Usage:**
```bash
source "$DOTFILES_DIR/lib/validation.sh"

# Validate inputs
validate_not_empty "$user_input" "username" || exit 1
validate_path "$filepath" "config_file" || exit 1
validate_command_exists "git" "git" || exit 1

# Sanitize output
safe_filename=$(sanitize_filename "$user_provided_name")
```

### 3. Error Handling Module (`lib/errors.sh`)

Robust error handling with cleanup and resource management.

**Key Functions:**
- `init_error_handling()` - Initialize error handlers (MUST call first)
- `on_exit()` - Register cleanup commands
- `try()` / `catch()` - Try-catch-like error handling
- `retry()` - Retry logic with configurable attempts and delay
- `timeout_exec()` - Execute with timeout protection
- `register_temp_file()` - Mark temporary file for automatic cleanup
- `register_temp_dir()` - Mark temporary directory for cleanup
- `push_context()` / `pop_context()` - Error context management
- `assert()` / `assert_equals()` - Assertion functions
- `assert_file_exists()` / `assert_file_not_exists()` - File assertions

**Usage:**
```bash
source "$DOTFILES_DIR/lib/errors.sh"

# Initialize at script start
init_error_handling

# Automatic cleanup
temp_file=$(mktemp)
register_temp_file "$temp_file"
# File automatically deleted on exit

# Error handling
if ! retry 3 5 "curl -f $url"; then
    error_report "Failed to download after 3 attempts"
    exit 1
fi

# Execute with timeout
timeout_exec 30 "long_running_command"
```

### 4. Audit Module (`lib/audit.sh`)

Comprehensive audit logging and compliance tracking.

**Key Functions:**
- `init_audit()` - Initialize audit system
- `audit_event()` - Log generic events
- `audit_action()` - Log user actions
- `audit_security()` - Log security events
- `audit_file_operation()` - Log file operations
- `audit_command()` - Log command execution
- `audit_package()` - Log package installations
- `audit_config_change()` - Log configuration changes
- `audit_summary()` - Get event summary
- `audit_recent()` - View recent events
- `rotate_audit_logs()` - Rotate old logs
- `archive_audit_logs()` - Archive logs
- `generate_audit_report()` - Create comprehensive report
- `check_compliance()` - Compliance checks

**Usage:**
```bash
source "$DOTFILES_DIR/lib/audit.sh"

# Initialize
init_audit
start_audit_session

# Log events
audit_event "INSTALLATION" "started"
audit_action "INSTALL" "package_name" "success"
audit_package "git" "homebrew" "2.40.0"

# View logs
audit_recent 10
audit_summary

# Cleanup
end_audit_session
```

---

## Features

### Input Validation & Sanitization

All user inputs are validated before use:
- Path traversal prevention
- Null byte detection
- Safe string patterns
- Regex-based validation
- Custom validators

### Error Handling & Recovery

Comprehensive error handling ensures graceful failures:
- Automatic signal handlers (SIGINT, SIGTERM)
- Resource cleanup on exit
- Nested error contexts
- Retry logic with exponential backoff
- Timeout protection

### Script Verification

Scripts are validated before execution:
- Bash syntax checking
- Shellcheck integration (when available)
- Signature verification
- Integrity checksums
- Permission auditing

### Audit Trails

All operations are logged for compliance:
- Timestamped event logs
- User action tracking
- File operation logs
- Command execution logs
- Security event logs

### Permission Hardening

File permissions are continuously verified:
- Secure default umask (0077)
- Sensitive file monitoring (.ssh, .aws, .gnupg)
- World-writable detection
- Script executable verification
- Directory access controls

### Secret Detection

Hardcoded secrets are detected and reported:
- Password pattern detection
- API key scanning
- AWS/Cloud credential detection
- Private key detection
- Sensitive config detection

---

## Best Practices

### 1. Always Initialize Error Handling

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/errors.sh"
init_error_handling  # MUST be first
```

### 2. Validate External Inputs

```bash
# Always validate user inputs
validate_not_empty "$filename" "filename" || exit 1
validate_path "$filepath" "filepath" || exit 1
validate_identifier "$var_name" "variable name" || exit 1
```

### 3. Use Try-Catch for Error Recovery

```bash
if ! try "risky_operation"; then
    catch $? || exit 1
    handle_error
fi
```

### 4. Register Cleanup Commands

```bash
# Automatically clean up temporary files
temp_dir=$(mktemp -d)
register_temp_dir "$temp_dir"
# Automatically removed on exit
```

### 5. Use Retry Logic for Network Operations

```bash
# Retry network calls with backoff
retry 3 5 "curl -fsSL https://example.com/file" || exit 1
```

### 6. Set Timeouts for Long Operations

```bash
# Prevent hanging on long operations
timeout_exec 300 "heavy_computation"
```

### 7. Log Important Operations

```bash
audit_event "DEPLOYMENT" "started" "version=$VERSION"
audit_action "UPDATE" "package_name" "success"
audit_event "DEPLOYMENT" "completed"
```

### 8. Regular Security Audits

```bash
# Run security verification
./scripts/verify-integrity.sh --all

# Run security tests
./scripts/security-tests.sh

# Generate audit report
./scripts/security-tests.sh > audit_report.txt
```

---

## Verification

### Integrity Verification

Verify the integrity of dotfiles installation:

```bash
# Generate checksums
./scripts/verify-integrity.sh --generate

# Verify all aspects
./scripts/verify-integrity.sh --all

# Verify specific aspect
./scripts/verify-integrity.sh --checksums
./scripts/verify-integrity.sh --permissions
./scripts/verify-integrity.sh --syntax

# Strict mode (fail on any issue)
./scripts/verify-integrity.sh --strict
```

### Security Testing

Run comprehensive security tests:

```bash
# Run all security tests
./scripts/security-tests.sh

# Run with verbose output
./scripts/security-tests.sh --verbose

# Tests include:
# - File permissions
# - Script syntax
# - Hardcoded secrets
# - Unexpected sudo usage
# - Git security
# - Environment isolation
```

---

## Audit Trail

### Accessing Audit Logs

Audit logs are stored in `.dotfiles_audit/`:

```bash
# View recent events
cat .dotfiles_audit/events.log

# View recent actions
cat .dotfiles_audit/actions.log

# View complete audit log
cat .dotfiles_audit/audit.log

# Search for specific events
grep "INSTALL" .dotfiles_audit/audit.log
```

### Audit Log Format

Main audit log format:
```
timestamp|level|user|hostname|category|action|details|session_id
```

### Maintaining Audit Logs

```bash
source lib/audit.sh

# Rotate logs (keep last 30 days)
rotate_audit_logs 30

# Archive logs
archive_audit_logs "./archive"

# Clean old logs (keep 90 days)
clean_audit_logs 90

# Generate report
generate_audit_report "./audit_report.txt"
```

---

## Testing

### Running Tests

```bash
# Run all security tests
./scripts/security-tests.sh

# Run integrity verification
./scripts/verify-integrity.sh --all

# Run smoke tests
./scripts/smoke-tests.sh
```

### Test Coverage

Security tests cover:

1. **Permission Tests**
   - Sensitive file permissions (.ssh, .aws, .kube)
   - Dotfiles directory permissions
   - Shell script permissions

2. **Syntax Tests**
   - Bash script syntax validation
   - Script execution permission checks

3. **Content Tests**
   - Hardcoded secrets detection
   - Unexpected sudo usage
   - Eval() usage detection

4. **Git Security**
   - Commit signatures
   - .gitignore secret patterns

5. **Environment Tests**
   - PATH and HOME verification
   - Umask security

6. **Module Tests**
   - Security module availability
   - Module sourcing verification

7. **Dependency Tests**
   - Required commands availability

---

## Security Checklist

Before deploying dotfiles, ensure:

- [ ] Run `./scripts/verify-integrity.sh --all`
- [ ] Run `./scripts/security-tests.sh`
- [ ] Review `.dotfiles_audit/events.log` for suspicious activity
- [ ] Verify no hardcoded secrets in scripts
- [ ] Confirm all scripts have valid syntax
- [ ] Check file permissions are secure (chmod 0700 for directories, 0600 for files)
- [ ] Ensure umask is set to 0077
- [ ] Verify git commits are signed (if required)
- [ ] Review .gitignore includes all sensitive patterns
- [ ] Generate checksums: `./scripts/verify-integrity.sh --generate`

---

## Reporting Issues

If you discover a security issue:

1. **Do NOT** create a public issue
2. **Email** security details to: [security contact]
3. **Include**: Description, affected version, reproduction steps
4. **Allow**: Reasonable time for patches before disclosure

---

## Additional Resources

- [OWASP Bash Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Bash.html)
- [Shellcheck](https://www.shellcheck.net/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

---

## Changelog

### v0.2.471 (2025-01-15)

**Security Enhancements:**
- Added comprehensive security module (`lib/security.sh`)
- Implemented input validation framework (`lib/validation.sh`)
- Added error handling with cleanup (`lib/errors.sh`)
- Implemented audit logging system (`lib/audit.sh`)
- Created integrity verification script (`scripts/verify-integrity.sh`)
- Added comprehensive security tests (`scripts/security-tests.sh`)
- Hardened bootstrap scripts with security checks
- Implemented automatic cleanup on script exit
- Added try-catch-like error handling
- Implemented retry logic with timeouts
- Added comprehensive audit trail

---

**Document Version:** 0.2.471  
**Last Updated:** 2025-01-15  
**Author:** Sebastien Rousseau  
**License:** MIT
