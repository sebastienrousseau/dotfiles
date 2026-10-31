#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by the plugins (through $DOT_SDK) and by lib/dot/utils.sh.
# The plugin SDK, v1 (P2.2): everything a bundled plugin may load from the
# host. A plugin sources "$DOT_SDK/sdk.sh" (bin/dot exports DOT_SDK, this
# directory) and, when it needs them, the other SDK files beside it:
# ui.sh, log.sh, platform.sh, preflight.sh, probe.sh, verified-download.sh
# and ai-roster.sh. tools/ci/check-plugin-imports.py fails a plugin
# that sources anything else outside its own directory.
#
# This file loads ui.sh, platform.sh and preflight.sh, and defines the
# helpers plugins call: the source tree, scripts, commands, messages and
# the command banner. lib/dot/utils.sh builds the host's helpers on it.
# Bash 3.2 compatible; inherits set -euo pipefail.

# Re-source guard: cheap short-circuit when sourced from multiple modules.
[[ "${_DOT_SDK_LOADED:-0}" == "1" ]] && return 0
_DOT_SDK_LOADED=1

_DOT_SDK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The SDK that loaded is the one a plugin started from here gets.
export DOT_SDK="$_DOT_SDK_DIR"
# shellcheck source=ui.sh
source "$_DOT_SDK_DIR/ui.sh"
# shellcheck source=platform.sh
source "$_DOT_SDK_DIR/platform.sh"
# shellcheck source=preflight.sh
source "$_DOT_SDK_DIR/preflight.sh"

_DOT_SOURCE_DIR_CACHE=""

## resolve_source_dir — Locate the dotfiles source tree.
## Checks (in order): relative to this script, $CHEZMOI_SOURCE_DIR,
## ~/.dotfiles, ~/.local/share/chezmoi. Caches the result for the process.
## Prints the absolute path (or empty string if not found). Exit: always 0.
resolve_source_dir() {
  if [[ -n "${_DOT_SOURCE_DIR_CACHE:-}" ]] && [[ -d "$_DOT_SOURCE_DIR_CACHE" ]]; then
    printf "%s\n" "$_DOT_SOURCE_DIR_CACHE"
    return
  fi

  local dir=""
  local repo_candidate=""

  # Post-Phase 1: lib lives at lib/dot/, so repo root is two levels up.
  # Pre-Phase 1 it was scripts/dot/lib/ (three levels up). Probe both for
  # safety while older deployments may still have the legacy layout.
  for candidate in "$_DOT_SDK_DIR/../.." "$_DOT_SDK_DIR/../../.."; do
    if repo_candidate="$(cd "$candidate" && pwd 2>/dev/null)"; then
      if [[ -n "$repo_candidate" && -f "$repo_candidate/lib/dot/ui.sh" ]]; then
        dir="$repo_candidate"
        break
      fi
    fi
  done
  if [[ -n "$dir" ]]; then
    :
  elif [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    dir="$CHEZMOI_SOURCE_DIR"
  elif [ -d "$HOME/.dotfiles" ]; then
    dir="$HOME/.dotfiles"
  elif [ -d "$HOME/.local/share/chezmoi" ]; then
    dir="$HOME/.local/share/chezmoi"
  fi

  if [ -n "$dir" ]; then
    # Resolve symlinks for consistent path handling
    if command -v realpath >/dev/null 2>&1; then
      dir="$(realpath "$dir")"
    elif command -v readlink >/dev/null 2>&1; then
      dir="$(readlink -f "$dir" 2>/dev/null || echo "$dir")"
    fi
    _DOT_SOURCE_DIR_CACHE="$dir"
    printf "%s\n" "$dir"
  else
    printf "%s\n" ""
  fi
}

## run_script — Resolve source dir, find a script, exec it (never returns).
## Usage: run_script <relative-script-path> <not-found-label> [args...]
## Exit: 1 if source dir or script not found; otherwise execs into the script.
run_script() {
  local script_rel="$1"
  local label="$2"
  shift 2
  local src_dir cm_src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  # Post-Phase-4b (v0.2.503) chezmoi-tracked content (dot_config/,
  # dot_local/, .chezmoitemplates/, …) lives under the subdir named
  # in `.chezmoiroot` (typically `defaults/`). Try the chezmoi-source
  # path first, fall back to the repo root for scripts/ + lib/ + bin/
  # which stay at the root regardless.
  cm_src_dir="$(resolve_chezmoi_source_dir)"
  if [ -n "$cm_src_dir" ] && [ -f "$cm_src_dir/$script_rel" ]; then
    exec bash "$cm_src_dir/$script_rel" "$@"
  elif [ -f "$src_dir/$script_rel" ]; then
    exec bash "$src_dir/$script_rel" "$@"
  else
    echo "$label not found." >&2
    exit 1
  fi
}

## require_source_dir — Print source dir path or exit 1 if not found.
require_source_dir() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  echo "$src_dir"
}

## resolve_chezmoi_source_dir — Print the path chezmoi treats as its
## source root. Post-Phase-4b (v0.2.503) this descends into the
## subdir named in .chezmoiroot (typically "defaults"). For chezmoi-
## tracked content (.chezmoidata.toml, .chezmoitemplates/, dot_config/,
## etc.). For scripts/, lib/, tools/ at the repo root, use
## resolve_source_dir instead.
resolve_chezmoi_source_dir() {
  local dir
  dir="$(resolve_source_dir)"
  [[ -z "$dir" ]] && return 0
  if [[ -f "$dir/.chezmoiroot" ]]; then
    local sub
    sub="$(head -1 "$dir/.chezmoiroot" | tr -d '[:space:]')"
    [[ -n "$sub" && -d "$dir/$sub" ]] && dir="$dir/$sub"
  fi
  printf "%s\n" "$dir"
}

## has_command <name> — Return 0 if <name> is on PATH, 1 otherwise.
has_command() {
  command -v "$1" >/dev/null 2>&1
}

## validate_name <name> [label] — Die if name contains unsafe characters.
## Allowed: [a-zA-Z0-9._-]. This prevents shell injection when names appear
## in paths or eval contexts. Exit: 0 if valid, calls die() if invalid.
validate_name() {
  local name="$1" label="${2:-name}"
  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    die "Invalid $label: $name (only alphanumeric, dash, underscore, dot allowed)"
  fi
}

## die <message> [code] — Print error to stderr and exit (default code 1).
die() {
  ui_err "$1" >&2
  exit "${2:-1}"
}

# Print warning message
warn() {
  ui_warn "$1" >&2
}

# Print info message
info() {
  ui_info "$1"
}

# Print the dot logo once per process for interactive sessions.
ui_logo_once() {
  local title="${1:-Dot}"
  ui_init
  if [[ "${DOTFILES_SHOW_LOGO:-1}" != "1" ]]; then
    return
  fi
  if [[ ! -t 1 ]]; then
    return
  fi
  if [[ "${DOTFILES_LOGO_PRINTED:-0}" = "1" ]]; then
    return
  fi
  ui_product_banner "$title"
}

dotfiles_version() {
  local src_dir version=""
  src_dir="$(resolve_source_dir)"

  if [[ -n "$src_dir" ]] && [[ -f "$src_dir/package.json" ]]; then
    version="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$src_dir/package.json" | head -1)"
  fi

  if [[ -z "$version" ]] && [[ -n "${DOTFILES_VERSION:-}" ]]; then
    version="$DOTFILES_VERSION"
  fi

  if [[ -z "$version" ]]; then
    version="unknown"
  fi

  printf "%s\n" "$version"
}

# dot_command_summary CMD: the command table's summary for CMD: the plugin's
# own `<domain> CMD` (bin/dot passes the domain as DOT_DOMAIN), else a
# domain or full command spelled CMD; a generic line when the table has
# none. The table is generated from the plugin manifests, so no command is
# described here.
dot_command_summary() {
  local summary=""
  [[ -n "${1:-}" && -f "$_DOT_SDK_DIR/data/commands.txt" ]] &&
    summary="$(awk -F'|' -v c="$1" -v d="${DOT_DOMAIN:-}" '
      $1 == "cmd" && d != "" && $2 == d " " c { own = $NF }
      ($1 == "dom" || $1 == "cmd") && $2 == c && any == "" { any = $NF }
      END { print (own != "" ? own : any) }' "$_DOT_SDK_DIR/data/commands.txt")"
  printf '%s\n' "${summary:-Run a dotfiles command.}"
}

dot_ui_command_banner() {
  local section="${1:-Dot}"
  local cmd="${2:-}"
  shift 2 || true
  local version summary

  for arg in "$@"; do
    case "$arg" in
      --json | -j)
        return
        ;;
    esac
  done

  ui_logo_once "Dot • $section"

  if [[ "${DOTFILES_SHOW_LOGO:-1}" != "1" ]] || [[ ! -t 1 ]]; then
    return
  fi

  version="$(dotfiles_version)"
  summary="$(dot_command_summary "$cmd")"

  ui_key_value "Version" "v${version}"
  if [[ -n "$cmd" ]]; then
    ui_key_value "Command" "dot ${cmd}"
  fi
  ui_key_value "Summary" "$summary"
  printf "\n"
}
