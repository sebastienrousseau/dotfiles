#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
#
# scripts/dot/commands/registry.sh
#
# `dot registry` — verified module registry for reusable chezmoi sources.
#
# §3 audit roadmap: ship a registry of reusable dotfile modules
# ("rust-dev-setup", "k8s-operator-laptop") to seed network effects.
# Hosted as a GitHub-Pages-indexed JSON file to keep ops cost near
# zero.
#
# Subcommands:
#   list           Show modules in the configured registry
#   search <q>     Filter modules by keyword (name, description, tags)
#   info <name>    Print full metadata for a module
#   install <name> Verify and preview a module; --yes applies it.
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
#         "archive_url": "https://example.com/rust-dev-setup-1.2.0.tar.gz",
#         "sha256": "<64 lowercase hexadecimal characters>" }
#     ]
#   }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/ui.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/ui.sh"
# shellcheck source=../../../lib/dot/utils.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/verified-download.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/verified-download.sh"

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

_registry_data_dir() {
  printf '%s/dotfiles/modules\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

_registry_validate_index() {
  local index="$1"
  jq -e '
    .version == 1 and
    (.modules | type == "array") and
    all(.modules[];
      (.name | test("^[a-z0-9][a-z0-9-]{0,31}$")) and
      (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+([+-][0-9A-Za-z.-]+)?$")) and
      (.description | type == "string" and length <= 200) and
      (.archive_url | test("^(https|file)://")) and
      (.sha256 | test("^[0-9a-f]{64}$"))
    )
  ' "$index" >/dev/null 2>&1
}

_registry_fetch() {
  local url cache_dir cache_file
  url="$(_registry_url)"
  [[ "$url" =~ ^(https://|file://) ]] || {
    ui_err "registry" "registry URL must use https:// (or file:// for local testing)"
    return 1
  }
  cache_dir="$(_registry_cache_dir)"
  cache_file="$cache_dir/index.json"
  mkdir -p "$cache_dir"
  # Refresh if older than 6h or missing.
  local now mtime
  now="$(date +%s)"
  if [[ -s "$cache_file" ]]; then
    if ! _registry_validate_index "$cache_file"; then
      rm -f "$cache_file"
    elif mtime="$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)"; then
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
  # `-fsSL -o file` should be silent, but with some upstreams (e.g.
  # GitHub Pages) curl still writes a stray newline to stdout. That
  # newline leaks into the caller's `$(_registry_fetch)` and later
  # into `jq FILE` as a two-argument invocation
  # (`jq \n /path/to/file`), producing a confusing
  # "Could not open file" error. Silence stdout explicitly.
  local curl_args=(-fsSL --max-time 15)
  if [[ "$url" == https://* ]]; then
    curl_args+=(--proto '=https' --tlsv1.2)
  fi
  if ! curl "${curl_args[@]}" -o "$tmp" "$url" >/dev/null; then
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
  if ! _registry_validate_index "$cache_file"; then
    rm -f "$cache_file"
    ui_err "registry" "index failed schema and integrity validation"
    return 1
  fi
  printf '%s\n' "$cache_file"
}

_registry_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    ui_err "registry" "jq is required"
    return 127
  }
}

_registry_archive_is_safe() {
  local archive="$1"
  local entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    if [[ "$entry" == /* || "$entry" == ../* || "$entry" == *"/../"* || "$entry" == *"/.." ]]; then
      ui_err "registry" "archive contains unsafe path: $entry"
      return 1
    fi
  done < <(tar -tzf "$archive")
  if tar -tvzf "$archive" | awk 'substr($1,1,1) == "l" || substr($1,1,1) == "h" { found=1 } END { exit !found }'; then
    ui_err "registry" "archive contains links; links are forbidden in registry modules"
    return 1
  fi
}

_registry_install() (
  local name="$1"
  local apply="${2:-0}"
  local index metadata version archive_url expected tmp archive extract module_root actual destination

  [[ "$name" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] || {
    ui_err "install" "invalid module name: $name"
    return 1
  }
  _registry_require_jq || return $?
  index="$(_registry_fetch)" || return $?
  _registry_validate_index "$index" || {
    ui_err "registry" "index failed schema validation"
    return 1
  }
  metadata="$(jq -c --arg name "$name" '.modules[] | select(.name == $name)' "$index")"
  [[ -n "$metadata" ]] || {
    ui_err "install" "module not found: $name"
    return 1
  }
  version="$(jq -r '.version' <<<"$metadata")"
  archive_url="$(jq -r '.archive_url' <<<"$metadata")"
  expected="$(jq -r '.sha256' <<<"$metadata")"

  tmp="$(mktemp -d -t dot-registry.XXXXXX)"
  archive="$tmp/module.tar.gz"
  extract="$tmp/source"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$extract"
  local curl_args=(-fsSL --max-time 60)
  if [[ "$archive_url" == https://* ]]; then
    curl_args+=(--proto '=https' --tlsv1.2)
  fi
  if ! curl "${curl_args[@]}" -o "$archive" "$archive_url"; then
    ui_err "install" "could not download $archive_url"
    return 1
  fi
  local archive_size
  archive_size="$(wc -c <"$archive" | tr -d '[:space:]')"
  if ((archive_size > 52428800)); then
    ui_err "install" "archive exceeds the 50 MiB safety limit"
    return 1
  fi
  actual="$(_dot_sha256_file "$archive")" || return $?
  [[ "$actual" == "$expected" ]] || {
    ui_err "install" "SHA-256 mismatch for $name@$version"
    return 1
  }
  _registry_archive_is_safe "$archive" || return $?
  tar -xzf "$archive" -C "$extract" --no-same-owner --no-same-permissions

  module_root="$extract"
  local roots=()
  while IFS= read -r entry; do roots+=("$entry"); done < <(find "$extract" -mindepth 1 -maxdepth 1 -print)
  if [[ ${#roots[@]} -eq 1 && -d "${roots[0]}" ]]; then
    module_root="${roots[0]}"
  fi
  [[ -n "$(find "$module_root" -mindepth 1 -print -quit)" ]] || {
    ui_err "install" "module archive is empty"
    return 1
  }

  ui_ok "Verified" "$name@$version ($actual)"
  ui_section "Chezmoi preview"
  chezmoi apply --source "$module_root" --destination "$HOME" --dry-run --no-tty
  if [[ "$apply" != "1" ]]; then
    ui_info "Preview only" "rerun with --yes to install and apply"
    return 0
  fi

  destination="$(_registry_data_dir)/$name/$version"
  mkdir -p "$(dirname "$destination")"
  rm -rf "$destination"
  mv "$module_root" "$destination"
  chezmoi apply --source "$destination" --destination "$HOME" --no-tty
  printf '%s\n' "$metadata" >"$(dirname "$destination")/installed.json"
  ui_ok "Installed" "$name@$version"
)

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
      # written file. Explicit if/else (avoid SC2015 A && B || C).
      local _tmp
      _tmp="$(mktemp "${cfg}.XXXXXX")"
      if printf 'url = "%s"\n' "$new_url" >"$_tmp"; then
        if ! mv "$_tmp" "$cfg"; then
          rm -f "$_tmp"
          ui_err "set-url" "failed to commit $cfg"
          return 1
        fi
      else
        rm -f "$_tmp"
        ui_err "set-url" "failed to write $cfg"
        return 1
      fi
      ui_ok "registry" "set to $new_url ($cfg)"
      ;;
    list)
      _registry_require_jq || return $?
      local index
      index="$(_registry_fetch)" || return $?
      ui_header "Registry modules"
      ui_info "Source" "$(_registry_url)"
      echo ""
      if ! jq -e '.modules | length > 0' "$index" >/dev/null 2>&1; then
        ui_warn "registry" "no modules published yet — see docs/operations/REGISTRY.md to contribute one"
        return 0
      fi
      ui_table_begin "Module" "Version" "Description"
      while IFS=$'\t' read -r name ver desc; do
        ui_table_add "$name" "v$ver" "$desc"
      done < <(jq -r '.modules[] | "\(.name)\t\(.version // "-")\t\(.description // "")"' "$index")
      ui_table_end
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
      echo ""
      ui_table_begin "Module" "Version" "Description"
      while IFS=$'\t' read -r name ver desc; do
        ui_table_add "$name" "v$ver" "$desc"
      done < <(jq -r --arg q "$q" '
        .modules[]
        | select(
            (.name // "" | ascii_downcase | contains($q | ascii_downcase)) or
            (.description // "" | ascii_downcase | contains($q | ascii_downcase)) or
            ((.tags // []) | map(ascii_downcase) | index($q | ascii_downcase))
          )
        | "\(.name)\t\(.version // "-")\t\(.description // "")"
      ' "$index")
      ui_table_end
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
      shift || true
      local apply=0
      case "${1:-}" in
        "") ;;
        --yes | -y) apply=1 ;;
        --dry-run | -n) apply=0 ;;
        *)
          ui_err "install" "unknown option: $1"
          return 2
          ;;
      esac
      _registry_install "$name" "$apply"
      ;;
    installed)
      _registry_require_jq || return $?
      local modules_dir
      modules_dir="$(_registry_data_dir)"
      if [[ ! -d "$modules_dir" ]]; then
        ui_info "registry" "no modules installed"
        return 0
      fi
      find "$modules_dir" -name installed.json -type f -exec jq -r '"\(.name)\t\(.version)\t\(.description)"' {} \; |
        while IFS=$'\t' read -r module version description; do
          ui_ok "$module" "v$version — $description"
        done
      ;;
    --help | -h | help)
      cat <<EOF
Usage: dot registry <subcommand>

Subcommands:
  list             List modules in the configured registry
  search <q>       Filter modules by keyword (name, description, tags)
  info <name>      Print metadata for a single module
  install <name>   Verify and preview a module; pass --yes to apply
  installed        List locally installed modules
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
