#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/*.sh and bin/dot; inherits set -euo pipefail.
# Dotfiles CLI Utilities
# The host's helpers, on top of the plugin SDK (sdk.sh), which it loads.
# The AI installer and the toolchain updater are not loaded here: the
# modules that use them source ai-provision.sh, ai-install.sh or
# upgrade.sh themselves.

# Re-source guard: cheap short-circuit when sourced from multiple modules.
[[ "${_DOT_LIB_UTILS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_UTILS_LOADED=1

# Lib-private: do NOT clobber the caller's SCRIPT_DIR. Callers in
# scripts/dot/commands/*.sh set SCRIPT_DIR to their own directory
# before sourcing us; reassigning it here breaks relative paths.
_DOT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The plugin SDK (ui, platform, preflight and the helpers plugins use);
# what follows is for the host and its own scripts.
# shellcheck source=sdk.sh
source "$_DOT_LIB_DIR/sdk.sh"

## sed_in_place — Portable in-place `sed` that works on GNU + BSD sed.
## GNU sed accepts `-i` with no argument; BSD (macOS) sed requires an
## empty extension argument (`-i ''`). Callers pass sed args exactly
## as they would to `sed`; the wrapper picks the right `-i` form
## based on `sed --version`.
## Args:  arguments passed verbatim to sed.
## Usage: sed_in_place -e 's/foo/bar/' path/to/file
## Note:  scripts/version-sync.sh keeps a specialised file-first
##        variant (`sed_in_place FILE ARGS...` with `-E`) for the
##        template-syncing pipeline; that one is intentionally distinct.
sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@" # GNU
  else
    sed -i '' "$@" # BSD (macOS)
  fi
}

## check_cmd — Test whether a command is invocable.
## Checks the process PATH first, then falls back to `mise ls --installed`
## so mise-managed tools (aqua:foo, npm:bar, plain foo) are recognised
## even when their shim hasn't been added to the current shell's PATH.
## Args:  $1 — command name to look up.
## Exit:  0 if available, 1 otherwise. Silent on stdout/stderr.
check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if command -v mise >/dev/null 2>&1; then
    # Exact tool name: `go` must not match `golangci-lint`, and the name
    # is data, not a regex. Backends prefix it (aqua:owner/name, npm:name).
    if mise ls --installed 2>/dev/null | awk -v c="$cmd" '
      { n = $1; if (n == c) f = 1; sub(/.*[:\/]/, "", n); if (n == c) f = 1 }
      END { exit !f }'; then
      return 0
    fi
  fi
  return 1
}

## validate_xdg_path <var_name> <path> — Warn and return 1 if path is not absolute.
validate_xdg_path() {
  local var_name="$1" path="$2"
  if [[ -n "$path" ]] && [[ "$path" != /* ]]; then
    ui_warn "$var_name" "Not an absolute path: $path (ignoring, using default)"
    return 1
  fi
  return 0
}

## ═════════════════════════════════════════════════════════════════
## HELP-FLAG SHORT-CIRCUIT
## Any command that accepts positional args from users MUST call
## `handle_help_flag` at entry — before any state-mutating logic
## (git ops, file writes, LLM calls, docker builds, editor spawns).
## Without this guard, `dot <cmd> --help` was treated as a data
## arg by many commands (audited 2026-07-05); some spent money
## (ai delegate), some opened editors and blocked on TTY (edit,
## sandbox), some invoked destructive subprocesses. Fix by
## short-circuiting to `dot help <cmd>` on --help / -h.
## ═════════════════════════════════════════════════════════════════

## is_help_flag — True (rc=0) iff any arg is --help or -h.
## Usage:
##   is_help_flag "$@" && { dot_show_help "backup"; return 0; }
is_help_flag() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --help | -h) return 0 ;;
      # `--` marks end of options; anything after is positional data.
      # Stop scanning so a literal `--help` value doesn't trigger.
      --) return 1 ;;
    esac
  done
  return 1
}

## dot_show_help — Print the canonical help for a subcommand and
## return 0. Delegates to `dot help <cmd>` (the same route users
## get from `dot help <cmd>` directly), which honours help formats
## and terminal capabilities.
##
## Usage (at command entry):
##   cmd_backup() {
##     is_help_flag "$@" && { dot_show_help "backup"; return 0; }
##     ...
##   }
dot_show_help() {
  local cmd="$1"
  local dot_cli
  local src_dir
  src_dir="$(resolve_source_dir)"
  dot_cli="${src_dir}/bin/dot"
  if [[ -x "$dot_cli" ]]; then
    "$dot_cli" help "$cmd"
  else
    # Fallback: just print the summary line if the dispatcher is
    # not reachable (unusual — implies the entire dot install is
    # broken, but at least give the user something).
    printf 'Usage: dot %s [args…]\n' "$cmd"
  fi
}

## handle_help_flag — Convenience wrapper for the common case:
##   if `--help`/`-h` in "$@", print help and return 0 to caller.
## The caller must propagate the return code.
##
## Usage:
##   cmd_backup() {
##     handle_help_flag "backup" "$@" && return 0
##     ...
##   }
handle_help_flag() {
  local cmd="$1"
  shift
  if is_help_flag "$@"; then
    dot_show_help "$cmd"
    return 0
  fi
  return 1
}
