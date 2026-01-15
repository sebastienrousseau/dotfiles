#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Error Handling Module
# File: lib/errors.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Robust error handling and cleanup framework
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

#------------------------------------------------------------------------------
# Error Handling Constants
#------------------------------------------------------------------------------

ERROR_HANDLER_VERSION="0.2.471"
export ERROR_HANDLER_VERSION
readonly ERROR_HANDLER_VERSION
readonly MAX_ERROR_DEPTH=10

# Global state
ERROR_COUNT=0
WARNING_COUNT=0
CLEANUP_STACK=()
SCRIPT_START_TIME="${SCRIPT_START_TIME:-$(date +%s)}"

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------

error_log() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

warn_log() {
    echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

info_log() {
    echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

debug_log() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
    fi
}

#------------------------------------------------------------------------------
# Error Reporting
#------------------------------------------------------------------------------

# Report an error with context
error_report() {
    local message="$1"
    local line_number="${2:-${BASH_LINENO[0]:-unknown}}"
    local function_name="${3:-${FUNCNAME[1]:-unknown}}"
    local exit_code="${4:-1}"
    
    ((ERROR_COUNT++))
    
    error_log "Error in $function_name (line $line_number): $message"
    
    return "$exit_code"
}

# Report a warning
warn_report() {
    local message="$1"
    local line_number="${2:-${BASH_LINENO[0]:-unknown}}"
    local function_name="${3:-${FUNCNAME[1]:-unknown}}"
    
    ((WARNING_COUNT++))
    
    warn_log "Warning in $function_name (line $line_number): $message"
}

#------------------------------------------------------------------------------
# Cleanup Stack Management
#------------------------------------------------------------------------------

# Register a cleanup command to be run on exit
on_exit() {
    local command="$1"
    
    if [[ ${#CLEANUP_STACK[@]} -ge $MAX_ERROR_DEPTH ]]; then
        warn_log "Cleanup stack overflow, ignoring command: $command"
        return
    fi
    
    CLEANUP_STACK+=("$command")
    debug_log "Registered cleanup: $command (stack size: ${#CLEANUP_STACK[@]})"
}

# Execute all registered cleanup commands in reverse order
execute_cleanup_stack() {
    local exit_code=$?
    local -i stack_index=${#CLEANUP_STACK[@]}-1
    
    debug_log "Executing cleanup stack (size: ${#CLEANUP_STACK[@]})"
    
    while [[ $stack_index -ge 0 ]]; do
        local command="${CLEANUP_STACK[$stack_index]}"
        debug_log "Executing cleanup: $command"
        
        # Execute cleanup command, but don't let it fail the entire cleanup
        eval "$command" || warn_log "Cleanup command failed: $command"
        
        ((stack_index--))
    done
    
    # Print summary
    if [[ $ERROR_COUNT -gt 0 ]]; then
        error_log "Script completed with $ERROR_COUNT error(s) and $WARNING_COUNT warning(s)"
    elif [[ $WARNING_COUNT -gt 0 ]]; then
        warn_log "Script completed with $WARNING_COUNT warning(s)"
    else
        info_log "Script completed successfully"
    fi
    
    return "$exit_code"
}

# Clear the cleanup stack (for testing)
clear_cleanup_stack() {
    CLEANUP_STACK=()
    debug_log "Cleanup stack cleared"
}

#------------------------------------------------------------------------------
# Signal Handlers
#------------------------------------------------------------------------------

# Handle script termination gracefully
setup_signal_handlers() {
    # Trap on exit to run cleanup
    trap execute_cleanup_stack EXIT
    
    # Trap on errors
    trap 'error_report "Unexpected error" "${BASH_LINENO[0]}" "${FUNCNAME[0]}" $?' ERR
    
    # Handle termination signals
    trap 'error_report "Received SIGTERM" "${BASH_LINENO[0]}" "${FUNCNAME[0]}"; exit 143' TERM
    trap 'error_report "Received SIGINT" "${BASH_LINENO[0]}" "${FUNCNAME[0]}"; exit 130' INT
}

#------------------------------------------------------------------------------
# Try-Catch-Like Error Handling
#------------------------------------------------------------------------------

# Try block - execute command and capture result
try() {
    local command="$@"
    local exit_code=0
    
    debug_log "Executing try block: $command"
    
    # Execute command and capture exit code
    if ! eval "$command"; then
        exit_code=$?
        debug_log "Try block failed with exit code $exit_code"
        return $exit_code
    fi
    
    return 0
}

# Catch block - handle errors from try block
catch() {
    local exit_code=$?
    local expected_code="${1:-1}"
    
    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi
    
    if [[ $exit_code -ne $expected_code ]] && [[ $expected_code -ne 0 ]]; then
        # Exit code doesn't match expectation
        return $exit_code
    fi
    
    debug_log "Caught error with exit code $exit_code"
    return 0
}

# Execute with retry logic
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local attempt=1
    
    shift 2
    local command="$@"
    
    while [[ $attempt -le $max_attempts ]]; do
        info_log "Attempt $attempt/$max_attempts: $command"
        
        if eval "$command"; then
            info_log "Command succeeded on attempt $attempt"
            return 0
        fi
        
        local exit_code=$?
        
        if [[ $attempt -lt $max_attempts ]]; then
            warn_log "Attempt $attempt failed (exit code: $exit_code), retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    error_log "Command failed after $max_attempts attempts"
    return 1
}

# Execute with timeout
timeout_exec() {
    local timeout="${1:-30}"
    shift
    local command="$@"
    
    debug_log "Executing with timeout: ${timeout}s: $command"
    
    # Use timeout command if available
    if command -v timeout &>/dev/null; then
        timeout "$timeout" bash -c "$command"
        return $?
    else
        # Fallback: execute in background with sleep-based check
        eval "$command" &
        local pid=$!
        local elapsed=0
        
        while [[ -e /proc/$pid ]] && [[ $elapsed -lt $timeout ]]; do
            sleep 1
            ((elapsed++))
        done
        
        if [[ -e /proc/$pid ]]; then
            error_log "Command timed out after ${timeout}s"
            kill -9 $pid 2>/dev/null || true
            return 124
        fi
        
        return 0
    fi
}

#------------------------------------------------------------------------------
# Resource Cleanup Helpers
#------------------------------------------------------------------------------

# Register temporary file for cleanup
register_temp_file() {
    local temp_file="$1"
    
    if [[ ! -e "$temp_file" ]]; then
        warn_log "Temporary file does not exist: $temp_file"
        return
    fi
    
    on_exit "rm -f '$temp_file'"
    debug_log "Registered temporary file for cleanup: $temp_file"
}

# Register temporary directory for cleanup
register_temp_dir() {
    local temp_dir="$1"
    
    if [[ ! -d "$temp_dir" ]]; then
        warn_log "Temporary directory does not exist: $temp_dir"
        return
    fi
    
    on_exit "rm -rf '$temp_dir'"
    debug_log "Registered temporary directory for cleanup: $temp_dir"
}

# Register process for cleanup (kill on exit)
register_background_process() {
    local pid="$1"
    
    on_exit "kill -9 $pid 2>/dev/null || true"
    debug_log "Registered background process for cleanup: $pid"
}

#------------------------------------------------------------------------------
# Error Context Management
#------------------------------------------------------------------------------

# Push error context (useful for nested operations)
push_context() {
    local context="$1"
    export CURRENT_CONTEXT="$context"
    debug_log "Pushed context: $context"
}

# Pop error context
pop_context() {
    unset CURRENT_CONTEXT
    debug_log "Popped context"
}

# Get error context
get_context() {
    echo "${CURRENT_CONTEXT:-global}"
}

#------------------------------------------------------------------------------
# Error Statistics
#------------------------------------------------------------------------------

# Get error count
get_error_count() {
    echo "$ERROR_COUNT"
}

# Get warning count
get_warning_count() {
    echo "$WARNING_COUNT"
}

# Reset error/warning counters
reset_counters() {
    ERROR_COUNT=0
    WARNING_COUNT=0
    debug_log "Error counters reset"
}

# Get script runtime
get_runtime() {
    local end_time
    end_time=$(date +%s)
    echo $((end_time - SCRIPT_START_TIME))
}

#------------------------------------------------------------------------------
# Assert Functions
#------------------------------------------------------------------------------

# Assert that a condition is true
assert() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if ! eval "$condition"; then
        error_report "$message (condition: $condition)" "${BASH_LINENO[0]}" "${FUNCNAME[1]}"
        return 1
    fi
    return 0
}

# Assert that two values are equal
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values not equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        error_report "$message (expected: $expected, actual: $actual)" "${BASH_LINENO[0]}" "${FUNCNAME[1]}"
        return 1
    fi
    return 0
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File does not exist: $file}"
    
    if [[ ! -f "$file" ]]; then
        error_report "$message" "${BASH_LINENO[0]}" "${FUNCNAME[1]}"
        return 1
    fi
    return 0
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file="$1"
    local message="${2:-File exists: $file}"
    
    if [[ -f "$file" ]]; then
        error_report "$message" "${BASH_LINENO[0]}" "${FUNCNAME[1]}"
        return 1
    fi
    return 0
}

#------------------------------------------------------------------------------
# Initialization
#------------------------------------------------------------------------------

# Initialize error handling (call at start of script)
init_error_handling() {
    setup_signal_handlers
    info_log "Error handling initialized"
}

################################################################################
# Export public functions (Bash only); Zsh does not support exporting functions
################################################################################
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f error_log
  export -f warn_log
  export -f info_log
  export -f debug_log
  export -f error_report
  export -f warn_report
  export -f on_exit
  export -f execute_cleanup_stack
  export -f clear_cleanup_stack
  export -f setup_signal_handlers
  export -f try
  export -f catch
  export -f retry
  export -f timeout_exec
  export -f register_temp_file
  export -f register_temp_dir
  export -f register_background_process
  export -f push_context
  export -f pop_context
  export -f get_context
  export -f get_error_count
  export -f get_warning_count
  export -f reset_counters
  export -f get_runtime
  export -f assert
  export -f assert_equals
  export -f assert_file_exists
  export -f assert_file_not_exists
  export -f init_error_handling
fi
