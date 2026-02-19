#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Shared logging functions for provision scripts
# Source this file at the top of any install/provision script.

set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_DOTFILES_LOGGING_LOADED:-}" ]]; then
    return 0
fi
_DOTFILES_LOGGING_LOADED=1

log_info()  { printf '\n[INFO] %s\n' "$*"; }
log_warn()  { printf '\n[WARN] %s\n' "$*" >&2; }
log_error() { printf '\n[ERROR] %s\n' "$*" >&2; }

die() {
    log_error "$@"
    exit 1
}
