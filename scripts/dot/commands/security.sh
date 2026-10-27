#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Security Commands
# backup (the hardening commands are plugins/security/dot-security)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Security" "${1:-}"

usage() {
  cat <<'EOF'
Usage: security.sh <command> [args...]

Commands:
  backup
EOF
}

cmd_backup() {
  run_script "scripts/security/backup.sh" "Backup script" "$@"
}

# Dispatch
case "${1:-}" in
  --help | -h | help)
    usage
    ;;
  "")
    usage
    exit 1
    ;;
  backup)
    shift
    cmd_backup "$@"
    ;;
  *)
    echo "Unknown security command: ${1:-}" >&2
    exit 1
    ;;
esac
