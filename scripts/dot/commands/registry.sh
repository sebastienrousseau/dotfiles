#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
# shellcheck source=../../../lib/dot/registry-trust.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/registry-trust.sh"
# shellcheck source=../../../lib/dot/registry-module.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/registry-module.sh"

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

## The index cache is keyed by URL, not by one fixed path.
##
## It used to live at <cache>/index.json for every registry, and be treated as
## fresh for six hours: a freshness window says nothing about WHICH registry
## produced the file, so changing DOTFILES_REGISTRY_URL — or running
## `dot registry set-url` — kept serving the previous registry's index for up
## to six hours. Keying by URL also means switching back and forth does not
## re-download.
##
## SHA-256 where a hasher exists, POSIX `cksum` otherwise: this is a cache
## key, not a security boundary, and every index is schema-validated on read.
_registry_cache_key() {
  local url="$1" digest=""
  if command -v shasum >/dev/null 2>&1; then
    digest="$(printf '%s' "$url" | shasum -a 256 2>/dev/null | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    digest="$(printf '%s' "$url" | sha256sum 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -z "$digest" ]]; then
    digest="$(printf '%s' "$url" | cksum | awk '{print $1 "-" $2}')"
  fi
  printf '%s\n' "${digest:0:32}"
}

## _registry_cache_file [url] — absolute path of the cached index for a URL
## (the active one by default). Tests seed the cache through this.
##
## v2: only indexes that passed signature verification are cached under this
## name, so a cache written before signing existed is never served. An index
## accepted unsigned (file:// with DOTFILES_REGISTRY_UNSIGNED=1) gets its own
## key, so it is not served later to a run that does verify.
_registry_cache_file() {
  local url="${1:-}"
  [[ -n "$url" ]] || url="$(_registry_url)"
  [[ "${DOTFILES_REGISTRY_UNSIGNED:-}" == "1" ]] && url="unsigned:$url"
  printf '%s/index-v2-%s.json\n' "$(_registry_cache_dir)" "$(_registry_cache_key "$url")"
}

_registry_data_dir() {
  printf '%s/dotfiles/modules\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

## _registry_validate_index <index> [index url]
## Archives must be https://, as the schema says; file:// archives are
## accepted only from an index that itself came from file:// (local
## development), so a remote index can never point at a local path.
_registry_validate_index() {
  local index="$1" archive_re='^https://'
  [[ "${2:-}" == file://* ]] && archive_re='^(https|file)://'
  jq -e --arg archive_re "$archive_re" '
    .version == 1 and
    (.updated == null or (.updated | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) and
    (.modules | type == "array") and
    all(.modules[];
      (.name | test("^[a-z0-9][a-z0-9-]{0,31}$")) and
      (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+([+-][0-9A-Za-z.-]+)?$")) and
      (.description | type == "string" and length <= 200) and
      (.archive_url | test($archive_re)) and
      (.sha256 | test("^[0-9a-f]{64}$"))
    )
  ' "$index" >/dev/null 2>&1
}

## _registry_fresh_cache <cache-file> <url> — succeed when a valid cached
## index is younger than six hours. An invalid one is removed.
_registry_fresh_cache() {
  local cache_file="$1" mtime
  [[ -s "$cache_file" ]] || return 1
  if ! _registry_validate_index "$cache_file" "$2"; then
    rm -f "$cache_file"
    return 1
  fi
  mtime="$(_registry_mtime "$cache_file")" || return 1
  (($(date +%s) - mtime < 21600))
}

## _registry_curl <url> <output> [max-time] — https is pinned to TLS 1.2+
## for the request and every redirect. `-fsSL -o file` should be silent, but
## with some upstreams (e.g. GitHub Pages) curl still writes a stray newline
## to stdout, which would leak into a caller's `$(_registry_fetch)` and then
## into `jq FILE` as a two-argument invocation. Silence stdout explicitly.
_registry_curl() {
  local curl_args=(-fsSL --max-time "${3:-15}")
  if [[ "$1" == https://* ]]; then
    curl_args+=(--proto '=https' --proto-redir '=https' --tlsv1.2)
  fi
  curl "${curl_args[@]}" -o "$2" "$1" >/dev/null
}

## _registry_accept <download> <signature> <url> <cache-file>
## Verify, validate and rollback-check a downloaded index, then cache it.
_registry_accept() {
  local tmp="$1" sig="$2" url="$3" cache_file="$4" key
  key="$(_registry_cache_key "$url")"
  _registry_verify_signature "$tmp" "$sig" "$url" || return $?
  if ! _registry_validate_index "$tmp" "$url"; then
    ui_err "registry" "index failed schema and integrity validation" >&2
    return 1
  fi
  _registry_check_rollback "$tmp" "$key" || return $?
  mv "$tmp" "$cache_file" || return $?
  _registry_record_floor "$cache_file" "$key"
}

## _registry_download_index <url> <cache-file> — fetch, verify and cache the
## index; on a failed fetch fall back to a recent cache. Diagnostics: stderr.
_registry_download_index() {
  local url="$1" cache_file="$2" tmp rc=0
  if ! command -v curl >/dev/null 2>&1; then
    ui_err "registry" "curl not installed" >&2
    return 127
  fi
  tmp="$(mktemp "${cache_file}.XXXXXX")"
  if ! _registry_curl "$url" "$tmp"; then
    rm -f "$tmp"
    _registry_stale_cache "$cache_file" && return 0
    ui_err "registry" "could not fetch $url" >&2
    return 1
  fi
  # A missing signature is not a fetch error: _registry_accept reports it.
  _registry_curl "$url.minisig" "$tmp.minisig" || rm -f "$tmp.minisig"
  _registry_accept "$tmp" "$tmp.minisig" "$url" "$cache_file" || rc=$?
  rm -f "$tmp" "$tmp.minisig"
  return "$rc"
}

# Prints the path of a verified, validated index file on stdout. Every
# diagnostic goes to stderr: stdout is this function's return channel, and
# callers read it with `index="$(_registry_fetch)"` — a warning printed here
# would be captured into that variable and then handed to jq as a filename.
_registry_fetch() {
  local url cache_file
  url="$(_registry_url)"
  [[ "$url" =~ ^(https://|file://) ]] || {
    ui_err "registry" "registry URL must use https:// (or file:// for local testing)" >&2
    return 1
  }
  cache_file="$(_registry_cache_file "$url")"
  mkdir -p "$(_registry_cache_dir)"
  if ! _registry_fresh_cache "$cache_file" "$url"; then
    _registry_download_index "$url" "$cache_file" || return $?
  fi
  printf '%s\n' "$cache_file"
}

_registry_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    ui_err "registry" "jq is required"
    return 127
  }
}

## _registry_archive_is_safe <archive> — refuse traversal, links and any
## chezmoi-active name (see _registry_forbidden_component), before anything
## is extracted and before chezmoi is ever called.
_registry_archive_is_safe() {
  local archive="$1" entry component
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    if [[ "$entry" == /* || "$entry" == ../* || "$entry" == *"/../"* || "$entry" == *"/.." ]]; then
      ui_err "registry" "archive contains unsafe path: $(_registry_clean_stream <<<"$entry")"
      return 1
    fi
    if component="$(_registry_forbidden_component "$entry")"; then
      ui_err "registry" "archive entry $(_registry_clean_stream <<<"$entry") is chezmoi-active content ($(_registry_clean_stream <<<"$component")); modules may only ship plain files"
      return 1
    fi
  done < <(tar -tzf "$archive")
  if tar -tvzf "$archive" | awk 'substr($1,1,1) == "l" || substr($1,1,1) == "h" { found=1 } END { exit !found }'; then
    ui_err "registry" "archive contains links; links are forbidden in registry modules"
    return 1
  fi
}

## _registry_download_archive <url> <output> <sha256> <label>
_registry_download_archive() {
  local url="$1" archive="$2" expected="$3" label="$4" archive_size actual
  if ! _registry_curl "$url" "$archive" 60; then
    ui_err "install" "could not download $url"
    return 1
  fi
  archive_size="$(wc -c <"$archive" | tr -d '[:space:]')"
  if ((archive_size > 52428800)); then
    ui_err "install" "archive exceeds the 50 MiB safety limit"
    return 1
  fi
  actual="$(_dot_sha256_file "$archive")" || return $?
  [[ "$actual" == "$expected" ]] || {
    ui_err "install" "SHA-256 mismatch for $label"
    return 1
  }
  ui_ok "Verified" "$label ($actual)"
}

## _registry_extract <archive> <dir> — extract, and set _REGISTRY_MODULE_ROOT
## to the module root (the single top-level directory, if the archive has
## one). Not printed: errors go to stdout like every install message.
_registry_extract() {
  local archive="$1" extract="$2" entry module_root roots=()
  tar -xzf "$archive" -C "$extract" --no-same-owner --no-same-permissions
  module_root="$extract"
  while IFS= read -r entry; do roots+=("$entry"); done < <(find "$extract" -mindepth 1 -maxdepth 1 -print)
  if [[ ${#roots[@]} -eq 1 && -d "${roots[0]}" ]]; then
    module_root="${roots[0]}"
  fi
  [[ -n "$(find "$module_root" -mindepth 1 -print -quit)" ]] || {
    ui_err "install" "module archive is empty"
    return 1
  }
  _REGISTRY_MODULE_ROOT="$module_root"
}

_registry_install() (
  local name="$1"
  local apply="${2:-0}"
  local index metadata version tmp archive module_root destination

  [[ "$name" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] || {
    ui_err "install" "invalid module name: $name"
    return 1
  }
  _registry_require_jq || return $?
  index="$(_registry_fetch)" || return $?
  _registry_validate_index "$index" "$(_registry_url)" || {
    ui_err "registry" "index failed schema validation"
    return 1
  }
  metadata="$(jq -c --arg name "$name" '.modules[] | select(.name == $name)' "$index")"
  [[ -n "$metadata" ]] || {
    ui_err "install" "module not found: $name"
    return 1
  }
  version="$(jq -r '.version' <<<"$metadata")"

  tmp="$(mktemp -d -t dot-registry.XXXXXX)"
  archive="$tmp/module.tar.gz"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/source"
  _registry_download_archive "$(jq -r '.archive_url' <<<"$metadata")" "$archive" \
    "$(jq -r '.sha256' <<<"$metadata")" "$name@$version" || return $?
  _registry_archive_is_safe "$archive" || return $?
  _registry_extract "$archive" "$tmp/source" || return $?
  module_root="$_REGISTRY_MODULE_ROOT"

  _registry_preview "$archive" "$module_root"
  if [[ "$apply" != "1" ]]; then
    ui_info "Preview only" "rerun with --yes to install and apply"
    return 0
  fi

  destination="$(_registry_data_dir)/$name/$version"
  mkdir -p "$(dirname "$destination")"
  rm -rf "$destination"
  mv "$module_root" "$destination"
  _registry_apply "$destination" "$tmp" || return $?
  _registry_installed_record "$metadata" "$destination" >"$(dirname "$destination")/installed.json"
  ui_ok "Installed" "$name@$version"
)

## _registry_table <index> [query] — the module table, every field scrubbed
## of control characters. An empty query lists every module.
_registry_table() {
  local name ver desc
  ui_table_begin "Module" "Version" "Description"
  while IFS=$'\t' read -r name ver desc; do
    ui_table_add "$name" "v$ver" "$desc"
  done < <(jq -r --arg q "${2:-}" "$_REGISTRY_JQ_CLEAN"'
    ($q | ascii_downcase) as $lq
    | .modules[]
    | select(
        $q == "" or
        (.name // "" | ascii_downcase | contains($lq)) or
        (.description // "" | ascii_downcase | contains($lq)) or
        ((.tags // []) | map(ascii_downcase) | index($lq))
      )
    | "\(.name | clean)\t\(.version // "-" | clean)\t\(.description // "" | clean)"
  ' "$1")
  ui_table_end
}

## _registry_info_rows <index> <name> — "key<TAB>value" rows, scrubbed.
_registry_info_rows() {
  jq -r --arg n "$2" "$_REGISTRY_JQ_CLEAN"'
    .modules[] | select(.name == $n) | to_entries[]
    | "\(.key | clean)\t\(.value | if type == "array" then map(clean) | join(", ") else clean end)"
  ' "$1"
}

_registry_help() {
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

The index must carry a valid minisign signature (<url>.minisig) from the
key in security/registry.pub. Modules may only ship plain files: templates,
scripts and other chezmoi-active names are refused, the preview is a diff,
and --yes applies without your chezmoi config or state.

Env overrides:
  DOTFILES_REGISTRY_URL       One-shot override of the registry URL.
  DOTFILES_REGISTRY_PUBKEY    Verify against another minisign public key.
  DOTFILES_REGISTRY_UNSIGNED  =1 skips signature checks for a file:// index
                              only (local development); prints a warning.

Default registry: $(_registry_default_url)
EOF
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
      # Refuse non-HTTPS schemes. The index is also minisign-verified on
      # every fetch; HTTPS keeps it confidential and fresh. The `file://`
      # exemption is for local testing only (the bench-script and unit
      # tests use it, with DOTFILES_REGISTRY_UNSIGNED=1).
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
      _registry_table "$index"
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
      _registry_table "$index" "$q"
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
      _registry_info_rows "$index" "$name" |
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
      find "$modules_dir" -name installed.json -type f -exec jq -r "$_REGISTRY_JQ_CLEAN"'"\(.name | clean)\t\(.version | clean)\t\(.description | clean)"' {} \; |
        while IFS=$'\t' read -r module version description; do
          ui_ok "$module" "v$version — $description"
        done
      ;;
    --help | -h | help)
      _registry_help
      ;;
    *)
      ui_err "Unknown subcommand" "$subcommand"
      echo "Run 'dot registry --help' for usage." >&2
      return 1
      ;;
  esac
}
