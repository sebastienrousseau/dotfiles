#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: doctor.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Health check and diagnostics for dotfiles setup
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

# Source portable abstractions
DOTFILES_ROOT="${HOME}/.dotfiles"
# shellcheck source=../lib/functions/portable.sh
source "${DOTFILES_ROOT}/lib/functions/portable.sh"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Check status
declare -i ERRORS=0
declare -i WARNINGS=0
declare -i CHECKS=0

# Configuration
PROFILE="${DOTFILES_DOCTOR_PROFILE:-default}"
AUDIT_MODE=0
METRICS_DIR="${HOME}/.dotfiles/metrics"
METRICS_FILE="${METRICS_DIR}/startup.json"

# Profile-based thresholds (in milliseconds)
# Format: profile:excellent:good:acceptable:blocker
declare -A PROFILE_THRESHOLDS
PROFILE_THRESHOLDS[default]="150:250:500:1000"
PROFILE_THRESHOLDS[laptop]="150:250:500:1000"
PROFILE_THRESHOLDS[server]="300:500:1000:2000"
PROFILE_THRESHOLDS[ci]="100:200:400:800"
PROFILE_THRESHOLDS[development]="200:300:600:1200"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

usage() {
    cat << EOF
dotfiles doctor - Health check and diagnostics for dotfiles

Usage: $(basename "$0") [OPTIONS]

Options:
    --profile PROFILE    Use performance profile (default, laptop, server, ci, development)
    --audit              Report only, never fail
    --baseline           Save current metrics as baseline
    --help, -h           Show this help message

Examples:
    $(basename "$0")                    # Use default profile
    $(basename "$0") --profile server   # Use server profile
    $(basename "$0") --audit            # Report only, don't fail
    $(basename "$0") --baseline         # Save current metrics

EOF
    exit 0
}

print_error() {
    if [[ $AUDIT_MODE -eq 1 ]]; then
        ((WARNINGS++))
        echo -e "  ${YELLOW}⚠${NC} [AUDIT] $1"
    else
        ((ERRORS++))
        echo -e "  ${RED}✗${NC} $1"
    fi
}

print_summary() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Summary${NC}"
    echo "  Total checks: $CHECKS"
    echo -e "  ${GREEN}Passed: $((CHECKS - ERRORS - WARNINGS))${NC}"
    [[ $WARNINGS -gt 0 ]] && echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
    [[ $ERRORS -gt 0 ]] && echo -e "  ${RED}Errors: $ERRORS${NC}"
    
    if [[ $AUDIT_MODE -eq 1 ]]; then
        echo -e "\n  ${BLUE}ℹ${NC}  Audit mode: All issues reported as warnings"
    fi
    
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ $AUDIT_MODE -eq 1 ]]; then
        echo -e "${BLUE}Status: Audit complete${NC}"
        return 0
    elif [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Status: Issues found that need attention${NC}"
        return 1
    else
        echo -e "${GREEN}Status: All checks passed!${NC}"
        return 0
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --audit)
                AUDIT_MODE=1
                shift
                ;;
            --baseline)
                save_baseline
                exit 0
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate profile
    if [[ -z "${PROFILE_THRESHOLDS[$PROFILE]:-}" ]]; then
        echo "Error: Unknown profile '$PROFILE'"
        echo "Available profiles: ${!PROFILE_THRESHOLDS[*]}"
        exit 1
    fi
}

get_threshold() {
    local level="$1"  # excellent, good, acceptable, blocker
    local thresholds="${PROFILE_THRESHOLDS[$PROFILE]}"
    
    case "$level" in
        excellent)  echo "${thresholds%%:*}" ;;
        good)       echo "$(echo "$thresholds" | cut -d: -f2)" ;;
        acceptable) echo "$(echo "$thresholds" | cut -d: -f3)" ;;
        blocker)    echo "$(echo "$thresholds" | cut -d: -f4)" ;;
    esac
}

print_header() {
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  🏥 Dotfiles Health Check${NC}"
    if [[ "$PROFILE" != "default" ]]; then
        echo -e "${BOLD}${BLUE}  📋 Profile: $PROFILE${NC}"
    fi
    if [[ $AUDIT_MODE -eq 1 ]]; then
        echo -e "${BOLD}${YELLOW}  🔍 Audit Mode: Report Only${NC}"
    fi
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_section() {
    echo -e "${BOLD}▸ $1${NC}"
}

check_pass() {
    ((++CHECKS))
    echo -e "  ${GREEN}✓${NC} $1"
}

check_warn() {
    ((++CHECKS))
    ((++WARNINGS))
    echo -e "  ${YELLOW}⚠${NC} $1"
}

check_fail() {
    ((++CHECKS))
    ((++ERRORS))
    echo -e "  ${RED}✗${NC} $1"
}

print_summary() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Summary${NC}"
    echo "  Total checks: $CHECKS"
    echo -e "  ${GREEN}Passed: $((CHECKS - ERRORS - WARNINGS))${NC}"
    [[ $WARNINGS -gt 0 ]] && echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
    [[ $ERRORS -gt 0 ]] && echo -e "  ${RED}Errors: $ERRORS${NC}"
    
    if [[ $AUDIT_MODE -eq 1 ]]; then
        echo -e "\n  ${BLUE}ℹ${NC}  Audit mode: All issues reported as warnings"
    fi
    
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ $AUDIT_MODE -eq 1 ]]; then
        echo -e "${BLUE}Status: Audit complete${NC}"
        return 0
    elif [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Status: Issues found that need attention${NC}"
        return 1
    else
        echo -e "${GREEN}Status: All checks passed!${NC}"
        return 0
    fi
}

save_baseline() {
    echo "Saving baseline metrics..."
    mkdir -p "$METRICS_DIR"
    
    # Measure current startup times
    local zsh_ms=0
    local bash_ms=0
    
    if command -v zsh &>/dev/null; then
        local zsh_output
        zsh_output=$( { time zsh -ilc exit; } 2>&1 )
        local zsh_time=$(echo "$zsh_output" | grep -E "real|total" | awk '{print $NF}' | head -1)
        
        if [[ "$zsh_time" =~ ([0-9.]+)m([0-9.]+)s ]]; then
            local minutes="${BASH_REMATCH[1]}"
            local seconds="${BASH_REMATCH[2]}"
            zsh_ms=$(awk "BEGIN {printf \"%.0f\", ($minutes * 60 + $seconds) * 1000}")
        elif [[ "$zsh_time" =~ ([0-9.]+)s ]]; then
            local seconds="${BASH_REMATCH[1]}"
            zsh_ms=$(awk "BEGIN {printf \"%.0f\", $seconds * 1000}")
        fi
    fi
    
    if command -v bash &>/dev/null; then
        local bash_output
        bash_output=$( { time bash -ilc exit; } 2>&1 )
        local bash_time=$(echo "$bash_output" | grep -E "real|total" | awk '{print $NF}' | head -1)
        
        if [[ "$bash_time" =~ ([0-9.]+)m([0-9.]+)s ]]; then
            local minutes="${BASH_REMATCH[1]}"
            local seconds="${BASH_REMATCH[2]}"
            bash_ms=$(awk "BEGIN {printf \"%.0f\", ($minutes * 60 + $seconds) * 1000}")
        elif [[ "$bash_time" =~ ([0-9.]+)s ]]; then
            local seconds="${BASH_REMATCH[1]}"
            bash_ms=$(awk "BEGIN {printf \"%.0f\", $seconds * 1000}")
        fi
    fi
    
    # Save to JSON
    cat > "$METRICS_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "profile": "$PROFILE",
  "hostname": "$(hostname)",
  "os": "$(uname -s)",
  "arch": "$(uname -m)",
  "startup_times": {
    "zsh_ms": $zsh_ms,
    "bash_ms": $bash_ms
  }
}
EOF
    
    echo "✓ Baseline saved to: $METRICS_FILE"
    echo "  Zsh: ${zsh_ms}ms"
    echo "  Bash: ${bash_ms}ms"
}

load_baseline() {
    if [[ -f "$METRICS_FILE" ]]; then
        # Simple JSON parsing with grep/sed
        local baseline_zsh=$(grep -o '"zsh_ms": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        local baseline_bash=$(grep -o '"bash_ms": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        echo "${baseline_zsh}:${baseline_bash}"
    else
        echo "0:0"
    fi
}

check_shell_startup_time() {
    print_section "Shell Startup Performance"
    
    local excellent=$(get_threshold excellent)
    local good=$(get_threshold good)
    local acceptable=$(get_threshold acceptable)
    local blocker=$(get_threshold blocker)
    
    # Load baseline if available
    local baseline=$(load_baseline)
    local baseline_zsh=$(echo "$baseline" | cut -d: -f1)
    local baseline_bash=$(echo "$baseline" | cut -d: -f2)
    
    # Zsh startup time
    if command -v zsh &>/dev/null; then
        local zsh_output
        zsh_output=$( { time zsh -ilc exit; } 2>&1 )
        local zsh_time=$(echo "$zsh_output" | grep -E "real|total" | awk '{print $NF}' | head -1)
        
        # Convert to milliseconds
        local zsh_ms=0
        if [[ "$zsh_time" =~ ([0-9.]+)m([0-9.]+)s ]]; then
            local minutes="${BASH_REMATCH[1]}"
            local seconds="${BASH_REMATCH[2]}"
            zsh_ms=$(awk "BEGIN {printf \"%.0f\", ($minutes * 60 + $seconds) * 1000}")
        elif [[ "$zsh_time" =~ ([0-9.]+)s ]]; then
            local seconds="${BASH_REMATCH[1]}"
            zsh_ms=$(awk "BEGIN {printf \"%.0f\", $seconds * 1000}")
        fi
        
        local msg="Zsh startup: ${zsh_ms}ms"
        
        # Add regression info if baseline exists
        if [[ $baseline_zsh -gt 0 ]]; then
            local diff=$((zsh_ms - baseline_zsh))
            if [[ $diff -gt 0 ]]; then
                msg="$msg (baseline: ${baseline_zsh}ms, +${diff}ms regression)"
            elif [[ $diff -lt 0 ]]; then
                msg="$msg (baseline: ${baseline_zsh}ms, ${diff}ms improvement)"
            else
                msg="$msg (baseline: ${baseline_zsh}ms, no change)"
            fi
        fi
        
        if [[ $zsh_ms -lt $excellent ]]; then
            check_pass "$msg (excellent)"
        elif [[ $zsh_ms -lt $good ]]; then
            check_pass "$msg (good)"
        elif [[ $zsh_ms -lt $acceptable ]]; then
            check_warn "$msg (acceptable, but could be faster)"
        elif [[ $zsh_ms -lt $blocker ]]; then
            check_fail "$msg (slow, approaching blocker threshold)"
        else
            check_fail "$msg (critical, exceeds ${blocker}ms threshold)"
        fi
    else
        check_warn "Zsh not installed or not in PATH"
    fi
    
    # Bash startup time
    if command -v bash &>/dev/null; then
        local bash_output
        bash_output=$( { time bash -ilc exit; } 2>&1 )
        local bash_time=$(echo "$bash_output" | grep -E "real|total" | awk '{print $NF}' | head -1)
        
        local bash_ms=0
        if [[ "$bash_time" =~ ([0-9.]+)m([0-9.]+)s ]]; then
            local minutes="${BASH_REMATCH[1]}"
            local seconds="${BASH_REMATCH[2]}"
            bash_ms=$(awk "BEGIN {printf \"%.0f\", ($minutes * 60 + $seconds) * 1000}")
        elif [[ "$bash_time" =~ ([0-9.]+)s ]]; then
            local seconds="${BASH_REMATCH[1]}"
            bash_ms=$(awk "BEGIN {printf \"%.0f\", $seconds * 1000}")
        fi
        
        local msg="Bash startup: ${bash_ms}ms"
        
        if [[ $baseline_bash -gt 0 ]]; then
            local diff=$((bash_ms - baseline_bash))
            if [[ $diff -gt 0 ]]; then
                msg="$msg (baseline: ${baseline_bash}ms, +${diff}ms regression)"
            elif [[ $diff -lt 0 ]]; then
                msg="$msg (baseline: ${baseline_bash}ms, ${diff}ms improvement)"
            else
                msg="$msg (baseline: ${baseline_bash}ms, no change)"
            fi
        fi
        
        if [[ $bash_ms -lt $excellent ]]; then
            check_pass "$msg (excellent)"
        elif [[ $bash_ms -lt $good ]]; then
            check_pass "$msg (good)"
        elif [[ $bash_ms -lt $acceptable ]]; then
            check_warn "$msg (acceptable, but could be faster)"
        elif [[ $bash_ms -lt $blocker ]]; then
            check_fail "$msg (slow, approaching blocker threshold)"
        else
            check_fail "$msg (critical, exceeds ${blocker}ms threshold)"
        fi
    else
        check_warn "Bash not installed or not in PATH"
    fi
    echo ""
}

check_required_files() {
    print_section "Required Files"
    
    local files=(
        "$HOME/.zshrc:Zsh configuration"
        "$HOME/.zshenv:Zsh environment"
        "$HOME/.bashrc:Bash configuration"
        "$HOME/.profile:Login profile"
        "$HOME/.dotfiles:Dotfiles directory"
        "$HOME/.dotfiles/lib:Dotfiles library"
    )
    
    for entry in "${files[@]}"; do
        IFS=: read -r file desc <<< "$entry"
        if [[ -e "$file" ]]; then
            check_pass "$desc exists"
        else
            check_warn "$desc missing: $file"
        fi
    done
    echo ""
}

check_duplicate_sourcing() {
    print_section "Duplicate Sourcing Detection"
    
    # Check for multiple compinit in zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        local compinit_count=$(grep -c "^[[:space:]]*compinit" "$HOME/.zshrc" 2>/dev/null || echo 0)
        if [[ $compinit_count -eq 0 ]]; then
            check_warn "No compinit found in .zshrc"
        elif [[ $compinit_count -eq 1 ]]; then
            check_pass "Single compinit call in .zshrc"
        else
            check_fail "Multiple compinit calls in .zshrc ($compinit_count times)"
        fi
    fi
    
    # Check for multiple mise activate
    if [[ -f "$HOME/.zshrc" ]]; then
        local mise_count=$(grep -c "mise activate" "$HOME/.zshrc" 2>/dev/null || echo 0)
        if [[ $mise_count -eq 0 ]]; then
            check_pass "No mise activate (or not using mise)"
        elif [[ $mise_count -eq 1 ]]; then
            check_pass "Single mise activate call"
        else
            check_fail "Multiple mise activate calls ($mise_count times)"
        fi
    fi
    
    # Check for circular sourcing
    if [[ -f "$HOME/.profile" ]] && [[ -f "$HOME/.bashrc" ]]; then
        if grep -q "source.*\.profile" "$HOME/.bashrc" 2>/dev/null; then
            if grep -q "source.*\.bashrc" "$HOME/.profile" 2>/dev/null; then
                check_fail "Circular sourcing detected between .profile and .bashrc"
            else
                check_pass "No circular sourcing detected"
            fi
        else
            check_pass "No circular sourcing detected"
        fi
    fi
    echo ""
}

check_path_sanity() {
    print_section "PATH Sanity Checks"
    
    # Count PATH entries
    local path_count=$(echo "$PATH" | tr ':' '\n' | wc -l | xargs)
    if [[ $path_count -lt 20 ]]; then
        check_pass "PATH has reasonable number of entries ($path_count)"
    elif [[ $path_count -lt 40 ]]; then
        check_warn "PATH has many entries ($path_count), might slow shell startup"
    else
        check_fail "PATH has excessive entries ($path_count), definitely impacting performance"
    fi
    
    # Check for duplicate PATH entries
    local duplicates=$(echo "$PATH" | tr ':' '\n' | sort | uniq -d | wc -l | xargs)
    if [[ $duplicates -eq 0 ]]; then
        check_pass "No duplicate PATH entries"
    else
        check_warn "Found $duplicates duplicate PATH entries"
    fi
    
    # Check for non-existent directories in PATH
    local missing=0
    while IFS= read -r dir; do
        [[ -d "$dir" ]] || ((missing++))
    done < <(echo "$PATH" | tr ':' '\n')
    
    if [[ $missing -eq 0 ]]; then
        check_pass "All PATH directories exist"
    else
        check_warn "$missing PATH directories don't exist"
    fi
    
    # Check for world-writable directories in PATH
    local writable=0
    while IFS= read -r dir; do
        if [[ -d "$dir" ]] && [[ -w "$dir" ]]; then
            local perms
            perms=$(get_file_perms "$dir")
            [[ "$perms" == *"777"* ]] && ((writable++))
        fi
    done < <(echo "$PATH" | tr ':' '\n')
    
    if [[ $writable -eq 0 ]]; then
        check_pass "No world-writable directories in PATH"
    else
        check_fail "$writable world-writable directories in PATH (security risk)"
    fi
    
    # Check for relative paths
    if echo "$PATH" | tr ':' '\n' | grep -q "^\."; then
        check_fail "Relative paths found in PATH (security risk)"
    else
        check_pass "No relative paths in PATH"
    fi
    echo ""
}

check_shell_syntax() {
    print_section "Shell Syntax Validation"
    
    if [[ -f "$HOME/.zshrc" ]]; then
        if zsh -n "$HOME/.zshrc" 2>/dev/null; then
            check_pass ".zshrc syntax is valid"
        else
            check_fail ".zshrc has syntax errors"
        fi
    fi
    
    if [[ -f "$HOME/.bashrc" ]]; then
        if bash -n "$HOME/.bashrc" 2>/dev/null; then
            check_pass ".bashrc syntax is valid"
        else
     arse_args "$@"
    
    p       check_fail ".bashrc has syntax errors"
        fi
    fi
    
    if [[ -f "$HOME/.profile" ]]; then
        if bash -n "$HOME/.profile" 2>/dev/null; then
            check_pass ".profile syntax is valid"
        else
            check_fail ".profile has syntax errors"
        fi
    fi
    echo ""
}

check_cache_status() {
    print_section "Cache Status"
    
    # Zsh cache
    if [[ -f "$HOME/.zsh_dotfiles_cache" ]]; then
        local age_seconds=$(( $(date +%s) - $(get_file_mtime "$HOME/.zsh_dotfiles_cache") ))
        local age_hours=$(( age_seconds / 3600 ))
        
        if [[ $age_hours -lt 24 ]]; then
            check_pass "Zsh dotfiles cache is fresh (${age_hours}h old)"
        else
            check_warn "Zsh dotfiles cache is stale (${age_hours}h old, >24h)"
        fi
    else
        check_warn "Zsh dotfiles cache doesn't exist (will be created on next shell start)"
    fi
    
    # Bash cache
    if [[ -f "$HOME/.bash_dotfiles_cache" ]]; then
        local age_seconds=$(( $(date +%s) - $(get_file_mtime "$HOME/.bash_dotfiles_cache") ))
        local age_hours=$(( age_seconds / 3600 ))
        
        if [[ $age_hours -lt 24 ]]; then
            check_pass "Bash dotfiles cache is fresh (${age_hours}h old)"
        else
            check_warn "Bash dotfiles cache is stale (${age_hours}h old, >24h)"
        fi
    else
        check_warn "Bash dotfiles cache doesn't exist"
    fi
    
    # Zsh completion dump
    if [[ -f "$HOME/.zcompdump" ]]; then
        local age_seconds=$(( $(date +%s) - $(get_file_mtime "$HOME/.zcompdump") ))
        local age_hours=$(( age_seconds / 3600 ))
        
        if [[ $age_hours -lt 24 ]]; then
            check_pass "Zsh completion cache is fresh (${age_hours}h old)"
        else
            check_pass "Zsh completion cache exists (${age_hours}h old)"
        fi
    else
        check_warn "Zsh completion cache doesn't exist"
    fi
    echo ""
}

check_environment_variables() {
    print_section "Environment Variables"
    
    [[ -n "${DOTFILES_VERSION:-}" ]] && check_pass "DOTFILES_VERSION is set: $DOTFILES_VERSION" || check_warn "DOTFILES_VERSION not set"
    [[ -n "${DOTFILES:-}" ]] && check_pass "DOTFILES is set: $DOTFILES" || check_warn "DOTFILES not set"
    [[ -n "${SHELL:-}" ]] && check_pass "SHELL is set: $SHELL" || check_fail "SHELL not set"
    [[ -n "${HOME:-}" ]] && check_pass "HOME is set: $HOME" || check_fail "HOME not set"
    
    echo ""
}

check_security() {
    print_section "Security Checks"
    
    # Check shell config file permissions
    for file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(get_file_perms "$file")
            if [[ "$perms" == "0644" ]] || [[ "$perms" == "0600" ]]; then
                check_pass "$(basename "$file") has safe permissions ($perms)"
            else
                check_warn "$(basename "$file") has unusual permissions ($perms)"
            fi
        fi
    done
    
    # Check for sensitive directories
    for dir in "$HOME/.ssh" "$HOME/.gnupg"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(get_file_perms "$dir")
            if [[ "$perms" == "0700" ]]; then
                check_pass "$(basename "$dir") has secure permissions ($perms)"
            else
                check_fail "$(basename "$dir") has insecure permissions ($perms), should be 0700"
            fi
        fi
    done
    
    echo ""
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    parse_args "$@"
    print_header
    
    check_shell_startup_time
    check_required_files
    check_duplicate_sourcing
    check_path_sanity
    check_shell_syntax
    check_cache_status
    check_environment_variables
    check_security
    
    print_summary
}

main "$@"
