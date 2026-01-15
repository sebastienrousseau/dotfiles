#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Input Validation Module
# File: lib/validation.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Input validation and sanitization framework
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

#------------------------------------------------------------------------------
# Validation Constants
#------------------------------------------------------------------------------

readonly VALIDATION_VERSION="0.2.471"

#------------------------------------------------------------------------------
# Error Reporting
#------------------------------------------------------------------------------

validation_error() {
    echo "[VALIDATION ERROR] $*" >&2
    return 1
}

validation_warn() {
    echo "[VALIDATION WARN] $*" >&2
}

#------------------------------------------------------------------------------
# String Validation
#------------------------------------------------------------------------------

# Validate that a string is not empty
validate_not_empty() {
    local value="$1"
    local field_name="${2:-value}"
    
    if [[ -z "$value" ]]; then
        validation_error "$field_name cannot be empty"
        return 1
    fi
    return 0
}

# Validate that a string matches a pattern
validate_pattern() {
    local value="$1"
    local pattern="$2"
    local field_name="${3:-value}"
    
    if [[ ! "$value" =~ $pattern ]]; then
        validation_error "$field_name does not match required pattern: $pattern (got: $value)"
        return 1
    fi
    return 0
}

# Validate string length
validate_length() {
    local value="$1"
    local min_length="${2:-0}"
    local max_length="${3:-999999}"
    local field_name="${4:-value}"
    
    local length=${#value}
    
    if [[ $length -lt $min_length ]] || [[ $length -gt $max_length ]]; then
        validation_error "$field_name length must be between $min_length and $max_length (got: $length)"
        return 1
    fi
    return 0
}

# Validate that a string only contains alphanumeric characters
validate_alphanumeric() {
    local value="$1"
    local field_name="${2:-value}"
    
    if [[ ! "$value" =~ ^[a-zA-Z0-9]+$ ]]; then
        validation_error "$field_name must only contain alphanumeric characters"
        return 1
    fi
    return 0
}

# Validate that a string is a valid identifier (letters, numbers, underscore, dash)
validate_identifier() {
    local value="$1"
    local field_name="${2:-value}"
    
    if [[ ! "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        validation_error "$field_name must be a valid identifier (start with letter/underscore, contain alphanumeric/underscore/dash)"
        return 1
    fi
    return 0
}

# Validate that a string is a valid path
validate_path() {
    local value="$1"
    local field_name="${2:-path}"
    
    if [[ -z "$value" ]]; then
        validation_error "$field_name cannot be empty"
        return 1
    fi
    
    # Check for path traversal attempts
    if [[ "$value" =~ \.\. ]]; then
        validation_error "$field_name contains path traversal sequence (..)"
        return 1
    fi
    
    # Check for null bytes
    if [[ "$value" == *$'\0'* ]]; then
        validation_error "$field_name contains null bytes"
        return 1
    fi
    
    return 0
}

# Validate that a string is a valid filename
validate_filename() {
    local value="$1"
    local field_name="${2:-filename}"
    
    # Must not be empty
    if [[ -z "$value" ]]; then
        validation_error "$field_name cannot be empty"
        return 1
    fi
    
    # Must not contain path separators
    if [[ "$value" == *"/"* ]]; then
        validation_error "$field_name must not contain path separators"
        return 1
    fi
    
    # Must not start with dot (hidden files)
    if [[ "$value" == .* ]]; then
        validation_warn "$field_name is a hidden file (starts with dot)"
    fi
    
    # Validate path traversal
    validate_path "$value" "$field_name" || return 1
    
    return 0
}

#------------------------------------------------------------------------------
# Numeric Validation
#------------------------------------------------------------------------------

# Validate that a value is an integer
validate_integer() {
    local value="$1"
    local field_name="${2:-value}"
    
    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        validation_error "$field_name must be an integer (got: $value)"
        return 1
    fi
    return 0
}

# Validate that a value is a positive integer
validate_positive_integer() {
    local value="$1"
    local field_name="${2:-value}"
    
    validate_integer "$value" "$field_name" || return 1
    
    if [[ $value -le 0 ]]; then
        validation_error "$field_name must be positive (got: $value)"
        return 1
    fi
    return 0
}

# Validate that a number is within range
validate_integer_range() {
    local value="$1"
    local min="${2:-0}"
    local max="${3:-100}"
    local field_name="${4:-value}"
    
    validate_integer "$value" "$field_name" || return 1
    
    if [[ $value -lt $min ]] || [[ $value -gt $max ]]; then
        validation_error "$field_name must be between $min and $max (got: $value)"
        return 1
    fi
    return 0
}

#------------------------------------------------------------------------------
# Email and Network Validation
#------------------------------------------------------------------------------

# Validate email address (basic pattern)
validate_email() {
    local value="$1"
    local field_name="${2:-email}"
    
    # Simple email validation pattern
    local email_pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    if [[ ! "$value" =~ $email_pattern ]]; then
        validation_error "$field_name is not a valid email address"
        return 1
    fi
    return 0
}

# Validate URL
validate_url() {
    local value="$1"
    local field_name="${2:-url}"
    
    # Basic URL validation
    local url_pattern='^https?://[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}(/.*)?$'
    
    if [[ ! "$value" =~ $url_pattern ]]; then
        validation_error "$field_name is not a valid URL"
        return 1
    fi
    return 0
}

# Validate IPv4 address
validate_ipv4() {
    local value="$1"
    local field_name="${2:-ipv4}"
    
    local ipv4_pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "$value" =~ $ipv4_pattern ]]; then
        validation_error "$field_name is not a valid IPv4 address"
        return 1
    fi
    
    # Validate each octet is <= 255
    local -a octets
    IFS='.' read -ra octets <<< "$value"
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]]; then
            validation_error "$field_name contains invalid octet (> 255): $octet"
            return 1
        fi
    done
    
    return 0
}

#------------------------------------------------------------------------------
# File and Directory Validation
#------------------------------------------------------------------------------

# Validate that a file exists and is readable
validate_readable_file() {
    local filepath="$1"
    local field_name="${2:-file}"
    
    if [[ ! -f "$filepath" ]]; then
        validation_error "$field_name does not exist: $filepath"
        return 1
    fi
    
    if [[ ! -r "$filepath" ]]; then
        validation_error "$field_name is not readable: $filepath"
        return 1
    fi
    return 0
}

# Validate that a file exists and is writable
validate_writable_file() {
    local filepath="$1"
    local field_name="${2:-file}"
    
    if [[ ! -f "$filepath" ]]; then
        validation_error "$field_name does not exist: $filepath"
        return 1
    fi
    
    if [[ ! -w "$filepath" ]]; then
        validation_error "$field_name is not writable: $filepath"
        return 1
    fi
    return 0
}

# Validate that a directory exists and is readable
validate_readable_directory() {
    local dirpath="$1"
    local field_name="${2:-directory}"
    
    if [[ ! -d "$dirpath" ]]; then
        validation_error "$field_name does not exist: $dirpath"
        return 1
    fi
    
    if [[ ! -r "$dirpath" ]]; then
        validation_error "$field_name is not readable: $dirpath"
        return 1
    fi
    return 0
}

# Validate that a directory exists and is writable
validate_writable_directory() {
    local dirpath="$1"
    local field_name="${2:-directory}"
    
    if [[ ! -d "$dirpath" ]]; then
        validation_error "$field_name does not exist: $dirpath"
        return 1
    fi
    
    if [[ ! -w "$dirpath" ]]; then
        validation_error "$field_name is not writable: $dirpath"
        return 1
    fi
    return 0
}

# Validate that a command exists
validate_command_exists() {
    local command="$1"
    local field_name="${2:-command}"
    
    if ! command -v "$command" &>/dev/null; then
        validation_error "$field_name not found in PATH: $command"
        return 1
    fi
    return 0
}

#------------------------------------------------------------------------------
# Input Sanitization
#------------------------------------------------------------------------------

# Remove leading/trailing whitespace
trim_whitespace() {
    local value="$1"
    # Remove leading whitespace
    value="${value#"${value%%[![:space:]]*}"}"
    # Remove trailing whitespace
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
}

# Convert to lowercase
to_lowercase() {
    local value="$1"
    echo "${value,,}"
}

# Convert to uppercase
to_uppercase() {
    local value="$1"
    echo "${value^^}"
}

# Escape special characters for safe shell use
escape_for_shell() {
    local value="$1"
    # Escape single quotes and wrap in quotes
    printf '%s\n' "${value//\'/\'\"\'\"\'}"
}

# Sanitize for safe use in filenames
sanitize_filename() {
    local value="$1"
    # Remove or replace unsafe characters
    value="${value//[^a-zA-Z0-9._-]/_}"
    # Remove leading dots
    value="${value#.}"
    echo "$value"
}

# Sanitize for safe use in variable names
sanitize_varname() {
    local value="$1"
    # Convert to uppercase and replace unsafe chars with underscore
    value="${value^^}"
    value="${value//[^A-Z0-9_]/_}"
    # Ensure it doesn't start with a number
    if [[ "$value" =~ ^[0-9] ]]; then
        value="_$value"
    fi
    echo "$value"
}

#------------------------------------------------------------------------------
# Validation Composition
#------------------------------------------------------------------------------

# Validate multiple conditions with custom error messages
validate_all() {
    local return_code=0
    
    # Process all arguments as individual validations
    # Each validation function should return 0 on success, 1 on failure
    for validation_func in "$@"; do
        if ! "$validation_func"; then
            return_code=1
        fi
    done
    
    return $return_code
}

# Validate one of multiple conditions (at least one must pass)
validate_any() {
    local return_code=1
    
    for validation_func in "$@"; do
        if "$validation_func"; then
            return_code=0
            break
        fi
    done
    
    if [[ $return_code -ne 0 ]]; then
        validation_error "None of the validation conditions were met"
    fi
    
    return $return_code
}

################################################################################
# Export public functions
################################################################################

export -f validate_not_empty
export -f validate_pattern
export -f validate_length
export -f validate_alphanumeric
export -f validate_identifier
export -f validate_path
export -f validate_filename
export -f validate_integer
export -f validate_positive_integer
export -f validate_integer_range
export -f validate_email
export -f validate_url
export -f validate_ipv4
export -f validate_readable_file
export -f validate_writable_file
export -f validate_readable_directory
export -f validate_writable_directory
export -f validate_command_exists
export -f trim_whitespace
export -f to_lowercase
export -f to_uppercase
export -f escape_for_shell
export -f sanitize_filename
export -f sanitize_varname
export -f validate_all
export -f validate_any
export -f validation_error
export -f validation_warn
