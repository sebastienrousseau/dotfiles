#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Audit Logging Module
# File: lib/audit.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Comprehensive audit trail and logging for dotfiles operations
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

#------------------------------------------------------------------------------
# Audit Constants
#------------------------------------------------------------------------------

readonly AUDIT_VERSION="0.2.471"
readonly AUDIT_DIR="${DOTFILES_AUDIT_DIR:-.dotfiles_audit}"
readonly AUDIT_LOG="${AUDIT_DIR}/audit.log"
readonly AUDIT_EVENTS="${AUDIT_DIR}/events.log"
readonly AUDIT_ACTIONS="${AUDIT_DIR}/actions.log"

# Audit event levels
readonly AUDIT_LEVEL_INFO=0
readonly AUDIT_LEVEL_WARN=1
readonly AUDIT_LEVEL_ERROR=2
readonly AUDIT_LEVEL_CRITICAL=3

#------------------------------------------------------------------------------
# Initialization
#------------------------------------------------------------------------------

# Initialize audit system
init_audit() {
    # Create audit directory if it doesn't exist
    if [[ ! -d "$AUDIT_DIR" ]]; then
        mkdir -p "$AUDIT_DIR" || {
            echo "Failed to create audit directory: $AUDIT_DIR" >&2
            return 1
        }
        chmod 0700 "$AUDIT_DIR" || true
    fi
    
    # Initialize log files if they don't exist
    touch "$AUDIT_LOG" "$AUDIT_EVENTS" "$AUDIT_ACTIONS" 2>/dev/null || true
    chmod 0600 "$AUDIT_LOG" "$AUDIT_EVENTS" "$AUDIT_ACTIONS" 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Audit Logging Functions
#------------------------------------------------------------------------------

# Log an audit event with timestamp and context
audit_log() {
    local level="$1"
    local category="$2"
    local action="$3"
    local details="${4:-}"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local user="${USER:-unknown}"
    local hostname="${HOSTNAME:-unknown}"
    local session_id="${AUDIT_SESSION_ID:-$(echo $$)}"
    
    # Format: timestamp|level|user|hostname|category|action|details|session_id
    local log_entry="$timestamp|$level|$user|$hostname|$category|$action|$details|$session_id"
    
    # Append to main audit log
    echo "$log_entry" >> "$AUDIT_LOG"
}

# Log a generic audit event
audit_event() {
    local category="$1"
    local event="$2"
    local details="${3:-}"
    
    audit_log "INFO" "$category" "$event" "$details"
    
    # Also write to events log with simpler format
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $category: $event${details:+ - $details}" >> "$AUDIT_EVENTS"
}

# Log a user action
audit_action() {
    local action="$1"
    local target="${2:-}"
    local result="${3:-success}"
    local details="${4:-}"
    
    audit_log "INFO" "ACTION" "$action" "target=$target|result=$result|details=$details"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $action on $target: $result${details:+ ($details)}" >> "$AUDIT_ACTIONS"
}

# Log a security-related event
audit_security() {
    local event="$1"
    local severity="${2:-INFO}"
    local details="${3:-}"
    
    local level="$AUDIT_LEVEL_INFO"
    case "$severity" in
        WARN)     level="$AUDIT_LEVEL_WARN" ;;
        ERROR)    level="$AUDIT_LEVEL_ERROR" ;;
        CRITICAL) level="$AUDIT_LEVEL_CRITICAL" ;;
    esac
    
    audit_log "$severity" "SECURITY" "$event" "$details"
}

# Log a file operation
audit_file_operation() {
    local operation="$1"  # create, modify, delete, read, write
    local filepath="$2"
    local details="${3:-}"
    
    audit_action "$operation" "$filepath" "success" "$details"
}

# Log a command execution
audit_command() {
    local command="$1"
    local exit_code="${2:-0}"
    local details="${3:-}"
    
    local result="success"
    if [[ $exit_code -ne 0 ]]; then
        result="failed (exit: $exit_code)"
    fi
    
    audit_action "EXECUTE" "$command" "$result" "$details"
}

# Log a package installation
audit_package() {
    local package="$1"
    local manager="${2:-unknown}"  # brew, apt, yum, etc.
    local version="${3:-}"
    local details="${4:-}"
    
    audit_action "INSTALL" "$package" "success" "manager=$manager|version=$version|details=$details"
}

# Log a configuration change
audit_config_change() {
    local config_file="$1"
    local old_value="${2:-}"
    local new_value="${3:-}"
    local details="${4:-}"
    
    audit_action "CONFIG_CHANGE" "$config_file" "success" "old=$old_value|new=$new_value|details=$details"
}

#------------------------------------------------------------------------------
# Audit Queries
#------------------------------------------------------------------------------

# Get audit log summary
audit_summary() {
    local timeframe="${1:-24h}"
    
    echo "=== Audit Summary ($timeframe) ==="
    echo ""
    echo "Total Events:"
    wc -l < "$AUDIT_LOG" 2>/dev/null || echo "0"
    echo ""
    echo "Event Types:"
    cut -d'|' -f5 "$AUDIT_LOG" 2>/dev/null | sort | uniq -c | sort -rn || true
    echo ""
    echo "Users:"
    cut -d'|' -f3 "$AUDIT_LOG" 2>/dev/null | sort | uniq -c || true
    echo ""
    echo "Error Events:"
    grep -c "ERROR" "$AUDIT_LOG" 2>/dev/null || echo "0"
}

# Get recent audit events
audit_recent() {
    local count="${1:-10}"
    
    echo "=== Recent Audit Events (last $count) ==="
    echo ""
    tail -n "$count" "$AUDIT_EVENTS" 2>/dev/null || echo "No events found"
}

# Get recent actions
audit_recent_actions() {
    local count="${1:-10}"
    
    echo "=== Recent Actions (last $count) ==="
    echo ""
    tail -n "$count" "$AUDIT_ACTIONS" 2>/dev/null || echo "No actions found"
}

# Search audit log for pattern
audit_search() {
    local pattern="$1"
    
    echo "=== Audit Log Matches for: $pattern ==="
    echo ""
    grep "$pattern" "$AUDIT_LOG" 2>/dev/null || echo "No matches found"
}

# Get audit log for specific user
audit_by_user() {
    local username="$1"
    
    echo "=== Audit Log for User: $username ==="
    echo ""
    grep "|$username|" "$AUDIT_LOG" 2>/dev/null || echo "No entries found for user: $username"
}

# Get audit log for specific action
audit_by_action() {
    local action="$1"
    
    echo "=== Audit Log for Action: $action ==="
    echo ""
    grep "|$action|" "$AUDIT_LOG" 2>/dev/null || echo "No entries found for action: $action"
}

# Get security events
audit_security_events() {
    echo "=== Security Events ==="
    echo ""
    grep "SECURITY" "$AUDIT_LOG" 2>/dev/null || echo "No security events found"
}

#------------------------------------------------------------------------------
# Audit Rotation and Maintenance
#------------------------------------------------------------------------------

# Rotate audit logs (keep last N days)
rotate_audit_logs() {
    local keep_days="${1:-30}"
    
    if [[ ! -f "$AUDIT_LOG" ]]; then
        return 0
    fi
    
    # Create backup with timestamp
    local backup_timestamp
    backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    
    cp "$AUDIT_LOG" "${AUDIT_LOG}.${backup_timestamp}"
    
    # Create temporary file for filtered logs
    local temp_log
    temp_log=$(mktemp)
    trap "rm -f '$temp_log'" RETURN
    
    # Find cutoff timestamp
    local cutoff_date
    cutoff_date=$(date -u -d "$keep_days days ago" '+%Y-%m-%d' 2>/dev/null || \
                   date -u -v-${keep_days}d '+%Y-%m-%d' 2>/dev/null)
    
    # Filter logs to keep only recent entries
    grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" "$AUDIT_LOG" | \
        awk -v cutoff="$cutoff_date" '$1 >= cutoff' > "$temp_log"
    
    # Replace original with filtered version
    mv "$temp_log" "$AUDIT_LOG"
    chmod 0600 "$AUDIT_LOG"
}

# Archive audit logs
archive_audit_logs() {
    local archive_dir="${1:-.dotfiles_audit_archive}"
    
    if [[ ! -d "$archive_dir" ]]; then
        mkdir -p "$archive_dir" || {
            echo "Failed to create archive directory: $archive_dir" >&2
            return 1
        }
    fi
    
    local archive_timestamp
    archive_timestamp=$(date '+%Y%m%d_%H%M%S')
    
    # Archive main audit log
    if [[ -f "$AUDIT_LOG" ]]; then
        gzip -c "$AUDIT_LOG" > "${archive_dir}/audit_${archive_timestamp}.log.gz" || true
    fi
    
    # Archive events log
    if [[ -f "$AUDIT_EVENTS" ]]; then
        gzip -c "$AUDIT_EVENTS" > "${archive_dir}/events_${archive_timestamp}.log.gz" || true
    fi
    
    # Archive actions log
    if [[ -f "$AUDIT_ACTIONS" ]]; then
        gzip -c "$AUDIT_ACTIONS" > "${archive_dir}/actions_${archive_timestamp}.log.gz" || true
    fi
}

# Clean old audit logs
clean_audit_logs() {
    local keep_days="${1:-90}"
    
    if [[ ! -d "$AUDIT_DIR" ]]; then
        return 0
    fi
    
    # Find and remove audit files older than keep_days
    find "$AUDIT_DIR" -type f -name "*.log" -mtime "+${keep_days}" -delete 2>/dev/null || true
    find "$AUDIT_DIR" -type f -name "*.log.gz" -mtime "+${keep_days}" -delete 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Audit Report Generation
#------------------------------------------------------------------------------

# Generate comprehensive audit report
generate_audit_report() {
    local output_file="${1:-.dotfiles_audit_report.txt}"
    
    {
        echo "======================================"
        echo "Dotfiles Audit Report"
        echo "======================================"
        echo ""
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo "=== Summary ==="
        audit_summary "all"
        echo ""
        
        echo "=== Recent Actions ==="
        audit_recent_actions 20
        echo ""
        
        echo "=== Security Events ==="
        audit_security_events
        echo ""
        
        echo "=== Audit Log ==="
        tail -n 50 "$AUDIT_LOG" 2>/dev/null || echo "No audit log entries"
        
    } > "$output_file"
    
    echo "Audit report generated: $output_file"
}

#------------------------------------------------------------------------------
# Session Management
#------------------------------------------------------------------------------

# Start a new audit session
start_audit_session() {
    export AUDIT_SESSION_ID="$(uuidgen 2>/dev/null || echo "$$-$(date +%s)")"
    audit_event "SESSION" "started" "session_id=$AUDIT_SESSION_ID"
}

# End current audit session
end_audit_session() {
    if [[ -n "${AUDIT_SESSION_ID:-}" ]]; then
        audit_event "SESSION" "ended" "session_id=$AUDIT_SESSION_ID"
        unset AUDIT_SESSION_ID
    fi
}

#------------------------------------------------------------------------------
# Compliance Helpers
#------------------------------------------------------------------------------

# Check audit log for compliance violations
check_compliance() {
    local days="${1:-7}"
    
    echo "=== Compliance Check (last $days days) ==="
    echo ""
    
    # Check for unauthorized access attempts
    local unauthorized
    unauthorized=$(grep -c "ERROR" "$AUDIT_LOG" 2>/dev/null || echo "0")
    echo "Failed operations: $unauthorized"
    
    # Check for privilege escalations (when not expected)
    local sudo_usage
    sudo_usage=$(grep -c "sudo" "$AUDIT_LOG" 2>/dev/null || echo "0")
    if [[ $sudo_usage -gt 0 ]]; then
        echo "⚠ Sudo usage detected: $sudo_usage"
    fi
    
    echo ""
}

################################################################################
# Export public functions (Bash only); Zsh does not support exporting functions
################################################################################
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f init_audit
  export -f audit_log
  export -f audit_event
  export -f audit_action
  export -f audit_security
  export -f audit_file_operation
  export -f audit_command
  export -f audit_package
  export -f audit_config_change
  export -f audit_summary
  export -f audit_recent
  export -f audit_recent_actions
  export -f audit_search
  export -f audit_by_user
  export -f audit_by_action
  export -f audit_security_events
  export -f rotate_audit_logs
  export -f archive_audit_logs
  export -f clean_audit_logs
  export -f generate_audit_report
  export -f start_audit_session
  export -f end_audit_session
  export -f check_compliance
fi
