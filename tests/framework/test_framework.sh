#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Minimal test framework helpers used by property_testing.sh
# Provides log_info and log_error used throughout the test infrastructure

# Colors (may already be set by assertions.sh — guard against re-declaration)
_TF_BLUE='\033[0;34m'
_TF_RED='\033[0;31m'
_TF_NC='\033[0m'

log_info() {
  printf '%b\n' "${_TF_BLUE}[INFO]${_TF_NC} $*" >&2
}

log_error() {
  printf '%b\n' "${_TF_RED}[ERROR]${_TF_NC} $*" >&2
}

log_warn() {
  printf '%b\n' "\033[0;33m[WARN]${_TF_NC} $*" >&2
}
