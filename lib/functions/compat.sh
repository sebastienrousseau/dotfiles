#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Compatibility Layer
# File: lib/functions/compat.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Cross-platform compatibility helpers
# Website: https://dotfiles.io
# License: MIT
################################################################################

# OS Detection
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

is_linux() {
    [[ "$OSTYPE" == "linux-gnu" ]]
}

is_ubuntu() {
    [[ -f /etc/os-release ]] && grep -qi ubuntu /etc/os-release
}

# Command Detection
has_cmd() {
    command -v "$1" &>/dev/null
}

ensure_cmd() {
    local cmd="$1"
    local msg="${2:-$cmd is required but not installed}"
    
    if ! has_cmd "$cmd"; then
        echo "Error: $msg" >&2
        return 1
    fi
}

# Shell Detection
is_bash() {
    [[ -n "${BASH_VERSION:-}" ]]
}

is_zsh() {
    [[ -n "${ZSH_VERSION:-}" ]]
}

# PATH Management
path_prepend() {
    local dir="$1"
    if [[ ":${PATH}:" != *":${dir}:"* ]]; then
        export PATH="${dir}:${PATH}"
    fi
}

path_append() {
    local dir="$1"
    if [[ ":${PATH}:" != *":${dir}:"* ]]; then
        export PATH="${PATH}:${dir}"
    fi
}

path_remove() {
    local dir="$1"
    export PATH="$(echo $PATH | tr ':' '\n' | grep -v "^${dir}$" | tr '\n' ':'  | sed 's/:$//')"
}

path_dedupe() {
    # Remove duplicate entries from PATH, keeping first occurrence
    if is_bash; then
        # Perl method for bash
        if command -v perl &>/dev/null; then
            export PATH="$(perl -e 'print join(":", grep { not $seen{$_}++ } split(/:/, $ENV{PATH}))')"
        else
            # Fallback pure bash method
            local new_path=""
            local IFS=":"
            local dir
            for dir in ${PATH}; do
                case ":${new_path}:" in
                    *:"${dir}":*) ;;
                    *) new_path="${new_path:+${new_path}:}${dir}" ;;
                esac
            done
            export PATH="${new_path}"
        fi
    fi
}

# File Operations
source_if_exists() {
    local file="$1"
    [[ -f "$file" ]] && source "$file"
}

ensure_file() {
    local file="$1"
    local msg="${2:-File not found: $file}"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: $msg" >&2
        return 1
    fi
}

ensure_dir() {
    local dir="$1"
    local msg="${2:-Directory not found: $dir}"
    
    if [[ ! -d "$dir" ]]; then
        echo "Error: $msg" >&2
        return 1
    fi
}

# Logging
log_info() {
    echo "ℹ $*"
}

log_warn() {
    echo "⚠ $*" >&2
}

log_error() {
    echo "✗ $*" >&2
}

log_success() {
    echo "✓ $*"
}

# Lazy Loading Helper
lazy_load() {
    local cmd="$1"
    local init_func="$2"
    
    # Create a wrapper function that loads the actual command on first use
    eval "
    $cmd() {
        # Source the initialization function
        $init_func
        
        # Now execute the actual command (which is now defined)
        $cmd \"\$@\"
    }
    "
}

# Version Comparison
version_ge() {
    # Check if version1 >= version2
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

version_gt() {
    # Check if version1 > version2
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" && "$1" != "$2" ]]
}

version_le() {
    # Check if version1 <= version2
    version_ge "$2" "$1"
}

version_lt() {
    # Check if version1 < version2
    version_gt "$2" "$1"
}

# JSON Query (requires jq)
json_get() {
    local file="$1"
    local path="$2"
    
    if has_cmd jq; then
        jq -r "$path" "$file" 2>/dev/null || echo ""
    fi
}

# System Info
get_os() {
    is_macos && echo "macos" && return 0
    is_ubuntu && echo "ubuntu" && return 0
    is_linux && echo "linux" && return 0
    echo "unknown"
}

get_arch() {
    uname -m
}

get_shell() {
    basename "$SHELL"
}

# Export all functions (Bash only - zsh doesn't support export -f)
# Temporarily disabled - causes zsh to crash
# if [ -n "${BASH_VERSION:-}" ]; then
#     export -f is_macos is_linux is_ubuntu 2>/dev/null || true
#     export -f has_cmd ensure_cmd 2>/dev/null || true
#     export -f is_bash is_zsh 2>/dev/null || true
#     export -f path_prepend path_append path_remove path_dedupe 2>/dev/null || true
#     export -f source_if_exists ensure_file ensure_dir 2>/dev/null || true
#     export -f log_info log_warn log_error log_success 2>/dev/null || true
#     export -f lazy_load 2>/dev/null || true
#     export -f version_ge version_gt version_le version_lt 2>/dev/null || true
#     export -f json_get get_os get_arch get_shell 2>/dev/null || true
# fi
