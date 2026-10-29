#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/ops/chezmoi-apply.sh, after names.sh and ui.sh.
# Plugin lifecycle hooks (P2.2, ADR-020). A plugin declares a hook in its
# manifest ([[hooks]]: event, run, summary); the generator writes it to the
# plugin's route fragment as
#
#   hook|<event>|<domain>|<script under the plugin dir>|<summary>
#
# and dot_hooks_run runs every hook for an event, in domain order, from the
# merged command table. Only bundled plugins' fragments are in the table
# (ADR-016), and a record whose domain or path is not of the declared shape
# is skipped. A hook that fails, or whose script is missing, is reported and
# the caller carries on.

[[ "${_DOT_LIB_HOOKS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_HOOKS_LOADED=1

# dot_hooks_run <event>: run each plugin's hook for the event. Hooks get
# DOT_HOOK_EVENT, and DOT_HOOK_INTERACTIVE from the caller's environment
# (1 when they may prompt). Always 0: a hook's failure is a warning.
dot_hooks_run() {
  local event="$1" kind ev domain run summary
  # The table is read, never cached, from here: the caller is not bin/dot,
  # so its cache key would not match the one bin/dot writes.
  _DOT_TABLE_READONLY=1 _dot_table_load
  while IFS='|' read -r kind ev domain run summary; do
    [[ "$kind" == hook && "$ev" == "$event" ]] || continue
    _dot_hook_one "$event" "$domain" "$run" "$summary"
  done <<<"$_DOT_TABLE"
  return 0
}

# _dot_hook_one <event> <domain> <run> <summary>: run one hook under its
# summary as a header.
_dot_hook_one() {
  local script="${_DOT_SRC:-.}/plugins/$2/$3"
  [[ "$2" =~ ^[a-z]{2,8}$ && "$3" =~ ^libexec/[a-z0-9][a-z0-9/_-]*\.sh$ ]] || return 0
  printf "\n"
  ui_header "$4"
  DOT_HOOK_EVENT="$1" bash "$script" || ui_warn "$2" "$1 hook failed (continuing)"
}
