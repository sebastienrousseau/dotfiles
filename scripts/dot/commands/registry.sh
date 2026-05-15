#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck shell=bash
#
# scripts/dot/commands/registry.sh
#
# `dot registry` — initial scaffold for the dot module registry.
#
# §3 audit roadmap: ship a registry of reusable dotfile modules
# ("rust-dev-setup", "k8s-operator-laptop") to seed network effects.
# Hosted as a GitHub-Pages-indexed JSON file to keep ops cost near
# zero.
#
# Current state: SCAFFOLD ONLY. This file ships the CLI surface and
# the JSON contract (see _registry_default_url). The registry itself
# is empty; populating it is its own roadmap item.
#
# Subcommands:
#   list           Show modules in the configured registry
#   search <q>     Filter modules by keyword (name, description, tags)
#   info <name>    Print full metadata for a module
#   install <name> Apply a module to the current workstation (stub —
#                  prints what would be installed; full implementation
#                  needs a sandboxed apply pipeline)
#   url            Show the active registry URL
#   set-url <u>    Override the registry URL (writes to user config)
#
# Registry JSON shape:
#   {
#     "version": 1,
#     "updated": "2026-05-15T16:00:00Z",
#     "modules": [
#       { "name": "rust-dev-setup",
#         "description": "Rust toolchain + cargo plugins + IDE config",
#         "repo": "https://github.com/example/rust-dev-setup",
#         "tags": ["rust", "dev", "language"],
#         "maintainer": "alice@example.com",
#         "version": "1.2.0",
#         "sha256": "abc123..." }
#     ]
#   }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/ui.sh disable=SC1091
source "$SCRIPT_DIR/../lib/ui.sh"
# shellcheck source=../lib/utils.sh disable=SC1091
source "$SCRIPT_DIR/../lib/utils.sh"

_registry_default_url() {
  printf '%s\n' "https://sebastienrousseau.github.io/dotfiles/registry.json"
}

_registry_config_file() {
  printf '%s/dotfiles/registry.toml\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

_registry_url() {
  if [[ -n "${DOTFILES_REGISTRY_URL:-}" ]]; then
    printf '%s\n' "$DOTFILES_REGISTRY_URL"
    return
  fi
  local cfg
  cfg="$(_registry_config_file)"
  if [[ -f "$cfg" ]]; then
    local u
    u="$(awk -F'[ \t]*=[ \t]*' '/^url[ \t]*=/{gsub(/"/,"",$2); print $2; exit}' "$cfg")"
    [[ -n "$u" ]] && {
      printf '%s\n' "$u"
      return
    }
  fi
  _registry_default_url
}

_registry_cache_dir() {
  printf '%s/dotfiles/registry\n' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

_registry_fetch() {
  local url cache_dir cache_file
  url="$(_registry_url)"
  cache_dir="$(_registry_cache_dir)"
  cache_file="$cache_dir/index.json"
  mkdir -p "$cache_dir"
  # Refresh if older than 6h or missing.
  local now mtime
  now="$(date +%s)"
  if [[ -s "$cache_file" ]]; then
    if mtime="$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)"; then
      if ((now - mtime < 21600)); then
        printf '%s\n' "$cache_file"
        return 0
      fi
    fi
  fi
  if ! command -v curl >/dev/null 2>&1; then
    ui_err "registry" "curl not installed"
    return 127
  fi
  local tmp
  tmp="$(mktemp "${cache_file}.XXXXXX")"
  if ! curl -fsSL --max-time 15 -o "$tmp" "$url"; then
    rm -f "$tmp"
    if [[ -s "$cache_file" ]]; then
      ui_warn "registry" "fetch failed; using stale cache at $cache_file"
      printf '%s\n' "$cache_file"
      return 0
    fi
    ui_err "registry" "could not fetch $url"
    return 1
  fi
  mv "$tmp" "$cache_file"
  printf '%s\n' "$cache_file"
}

_registry_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    ui_err "registry" "jq is required"
    return 127
  }
}

cmd_registry() {
  local subcommand="${1:-list}"
  shift || true

  case "$subcommand" in
    url)
      printf '%s\n' "$(_registry_url)"
      ;;
    set-url)
      local new_url="${1:-}"
      [[ -n "$new_url" ]] || {
        ui_err "set-url" "missing URL"
        return 1
      }
      # Refuse non-HTTPS schemes. The registry index is unsigned today,
      # so HTTPS is the only transport that gives us cert-pinned
      # integrity. The `file://` exemption is for local testing only
      # (the bench-script and unit tests use it).
      if [[ ! "$new_url" =~ ^(https://|file://) ]]; then
        ui_err "set-url" "registry URL must use https:// (or file:// for local testing) — got: $new_url"
        return 1
      fi
      local cfg
      cfg="$(_registry_config_file)"
      mkdir -p "$(dirname "$cfg")"
      # Atomic write so a concurrent invocation can't read a half-
      # written file.
      local _tmp
      _tmp="$(mktemp "${cfg}.XXXXXX")"
      printf 'url = "%s"\n' "$new_url" >"$_tmp" && mv "$_tmp" "$cfg" ||
        {
          rm -f "$_tmp"
          ui_err "set-url" "failed to write $cfg"
          return 1
        }
      ui_ok "registry" "set to $new_url ($cfg)"
      ;;
    list)
      _registry_require_jq || return $?
      local index
      index="$(_registry_fetch)" || return $?
      ui_header "Registry modules"
      ui_info "Source" "$(_registry_url)"
      if ! jq -e '.modules | length > 0' "$index" >/dev/null 2>&1; then
        ui_warn "registry" "no modules published yet — see docs/operations/REGISTRY.md to contribute one"
        return 0
      fi
      jq -r '.modules[] | "\(.name)\t\(.version // "-")\t\(.description // "")"' "$index" |
        while IFS=$'\t' read -r name ver desc; do
          ui_ok "$name" "v$ver  $desc"
        done
      ;;
    search)
      _registry_require_jq || return $?
      local q="${1:-}"
      [[ -n "$q" ]] || {
        ui_err "search" "missing query"
        return 1
      }
      local index
      index="$(_registry_fetch)" || return $?
      ui_header "Registry search: $q"
      jq -r --arg q "$q" '
        .modules[]
        | select(
            (.name // "" | ascii_downcase | contains($q | ascii_downcase)) or
            (.description // "" | ascii_downcase | contains($q | ascii_downcase)) or
            ((.tags // []) | map(ascii_downcase) | index($q | ascii_downcase))
          )
        | "\(.name)\t\(.version // "-")\t\(.description // "")"
      ' "$index" | while IFS=$'\t' read -r name ver desc; do
        ui_ok "$name" "v$ver  $desc"
      done
      ;;
    info)
      _registry_require_jq || return $?
      local name="${1:-}"
      [[ -n "$name" ]] || {
        ui_err "info" "missing module name"
        return 1
      }
      local index
      index="$(_registry_fetch)" || return $?
      local found
      found="$(jq -r --arg n "$name" '.modules[] | select(.name == $n) | "OK"' "$index" 2>/dev/null)"
      if [[ "$found" != "OK" ]]; then
        ui_err "info" "module not found: $name"
        return 1
      fi
      jq -r --arg n "$name" '.modules[] | select(.name == $n) | to_entries[] | "\(.key)\t\(.value | if type == "array" then join(", ") else tostring end)"' "$index" |
        while IFS=$'\t' read -r key value; do
          ui_ok "$key" "$value"
        done
      ;;
    install)
      local name="${1:-}"
      [[ -n "$name" ]] || {
        ui_err "install" "missing module name"
        return 1
      }
      ui_warn "install" "scaffold only — full module installer is a roadmap item"
      ui_info "install" "would fetch module $name from registry and apply it as a chezmoi sub-source"
      return 0
      ;;
    --help | -h | help)
      cat <<EOF
Usage: dot registry <subcommand>

Subcommands:
  list             List modules in the configured registry
  search <q>       Filter modules by keyword (name, description, tags)
  info <name>      Print metadata for a single module
  install <name>   Install a module (scaffold — see docs/operations/REGISTRY.md)
  url              Show the active registry URL
  set-url <url>    Override the registry URL (persists to user config)

Env overrides:
  DOTFILES_REGISTRY_URL   One-shot override of the registry URL.

Default registry: $(_registry_default_url)
EOF
      ;;
    *)
      ui_err "Unknown subcommand" "$subcommand"
      echo "Run 'dot registry --help' for usage." >&2
      return 1
      ;;
  esac
}
