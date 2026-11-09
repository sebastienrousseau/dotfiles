#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot ai policy check [--policy FILE] — validate the AI policy (ADR-025)
# and name its modes and the active one. dot-policy, built from
# ~/.local/share/dot-policy, does the work; dot cli hook check is the hook
# that enforces it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/sdk.sh
source "${DOT_SDK:-$SCRIPT_DIR/../../../lib/dot}/sdk.sh"

bin="${DOT_POLICY_BIN:-$HOME/.local/bin/dot-policy}"
case "${1:-}" in
  check) shift ;;
  *)
    echo "Usage: dot ai policy check [--policy FILE]"
    exit 1
    ;;
esac
[[ -x "$bin" ]] || {
  ui_err "dot-policy" "not built: install Go with mise, then chezmoi apply" >&2
  exit 1
}
exec "$bin" validate "$@"
