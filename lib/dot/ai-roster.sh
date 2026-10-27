#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by lib/dot/ai-commands.sh, lib/dot/ai-install.sh and
# scripts/diagnostics/doctor.sh.
# Lookups over the AI roster. The data (lib/dot/data/ai-roster.sh) is
# generated from plugins/ai/roster.toml by tools/docs/gen_roster.py; no AI
# tool list is written by hand anywhere else.

# Re-source guard: cheap short-circuit when sourced from multiple modules.
[[ "${_DOT_LIB_AI_ROSTER_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_AI_ROSTER_LOADED=1

# shellcheck source=data/ai-roster.sh disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/data/ai-roster.sh"

# _ai_roster_get <table> <key>: the value after "<key>=" in a generated
# table; 1 when the key is absent.
_ai_roster_get() {
  local line
  while IFS= read -r line; do
    if [[ "${line%%=*}" == "$2" ]]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  done <<<"$1"
  return 1
}

# ai_roster_bin <name|alias>: the tool's binary; 1 for a name not in the roster.
ai_roster_bin() { _ai_roster_get "$AI_ROSTER_BIN_OF" "$1"; }

# ai_roster_package <binary>: its mise package; 1 when it has none.
ai_roster_package() { _ai_roster_get "$AI_ROSTER_PACKAGE_OF" "$1"; }

# ai_roster_native <binary>: its native installer function; 1 when it has none.
ai_roster_native() { _ai_roster_get "$AI_ROSTER_NATIVE_OF" "$1"; }
