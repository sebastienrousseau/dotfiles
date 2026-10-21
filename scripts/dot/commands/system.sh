#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## dot system: status and the scheduled maintenance job.
## Usage: dot system [status] | dot system schedule [list|set weekly|daily|off|run]
## `dot system update` runs cmd_upgrade (route upgrade).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/system.sh
source "$SCRIPT_DIR/../../../lib/dot/system.sh"

# _system_unknown: the words are left out, since one may be a secret.
_system_unknown() {
  printf "dot: unknown 'dot system' command; see 'dot help system'\n" >&2
  exit 1
}

_system_schedule() {
  case "${1:-list}" in
    list) dot_system_schedule_list ;;
    set)
      shift
      dot_system_schedule_set "$@"
      ;;
    run) dot_system_schedule_run ;;
    *) _system_unknown schedule "$@" ;;
  esac
}

case "${1:-status}" in
  status) dot_system_status ;;
  schedule)
    shift
    _system_schedule "$@"
    ;;
  *) _system_unknown "$@" ;;
esac
