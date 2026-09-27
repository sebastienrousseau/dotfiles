#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Aliases Commands (extracted from tools.sh)
# aliases list|search|why|stats|cheatsheet|tiers, alias-check

set -euo pipefail

# Guard: only define functions, do not execute on source
# These functions are sourced by tools.sh for dispatch.

alias_manifest_path() {
  local src_dir
  src_dir="$(require_source_dir)"
  printf "%s\n" "$src_dir/scripts/diagnostics/aliases-manifest.sh"
}

emit_alias_manifest() {
  local manifest
  manifest="$(alias_manifest_path)"
  if [[ ! -x "$manifest" ]]; then
    die "Alias manifest script not found: $manifest"
  fi
  bash "$manifest"
}

alias_tier_enabled() {
  local csv="${1:-all}"
  local token="${2:-}"
  if [[ "$csv" == "all" ]]; then
    return 0
  fi
  [[ ",${csv}," == *",${token},"* ]]
}

_aliases_list() {
  local name value file line
  ui_header "Aliases"
  echo ""
  ui_table_begin "Name" "Value" "Source"
  while IFS=$'\t' read -r name value file line; do
    ui_table_add "$name" "${value:0:60}" "${file##*/}:$line"
  done < <(emit_alias_manifest | sort -t $'\t' -k1,1)
  ui_table_end
}

_aliases_search() {
  local query="${1:-}" results name value file line
  if [[ -z "$query" ]]; then
    die "Usage: dot aliases search <term>"
  fi
  ui_header "Alias Search"
  ui_info "Query" "$query"
  echo ""
  # rg where present, grep otherwise: the manifest itself already falls
  # back to grep, and without this a host without rg answered every
  # query with "No matches".
  if command -v rg >/dev/null 2>&1; then
    results="$(emit_alias_manifest | rg -i "$query" || true)"
  else
    results="$(emit_alias_manifest | grep -Ei "$query" || true)"
  fi
  if [[ -z "$results" ]]; then
    ui_warn "No matches" "$query"
    return 1
  fi
  ui_table_begin "Name" "Value" "Source"
  while IFS=$'\t' read -r name value file line; do
    ui_table_add "$name" "${value:0:60}" "$file:$line"
  done <<<"$results"
  ui_table_end
}

# The deprecation record for an alias, if any; prints it and sets the
# caller's deprecation.
_aliases_why_deprecation() {
  local alias_name="$1" src_dir deprecations_file _a replacement remove_in note
  src_dir="$(require_source_dir)"
  deprecations_file="$src_dir/scripts/dot/data/alias-deprecations.tsv"
  [[ -f "$deprecations_file" ]] || return 0
  deprecation="$(awk -F'\t' -v a="$alias_name" 'BEGIN{IGNORECASE=0} $1 !~ /^#/ && $1==a {print $0; exit}' "$deprecations_file")"
  [[ -n "$deprecation" ]] || return 0
  IFS=$'\t' read -r _a replacement remove_in note <<<"$deprecation"
  echo ""
  ui_warn "Deprecated" "yes"
  ui_info "Replacement" "$replacement"
  ui_info "Remove In" "$remove_in"
  ui_info "Note" "$note"
}

_aliases_why() {
  local alias_name="${1:-}" rows deprecation="" name value file line
  if [[ -z "$alias_name" ]]; then
    die "Usage: dot aliases why <alias>"
  fi
  ui_header "Alias Details"
  ui_info "Alias" "$alias_name"
  echo ""
  rows="$(emit_alias_manifest | awk -F'\t' -v a="$alias_name" '$1==a')"
  if [[ -n "$rows" ]]; then
    printf "%s\n" "$rows" | while IFS=$'\t' read -r name value file line; do
      ui_ok "$name" "${value}"
      printf "    source: %s:%s\n" "$file" "$line"
    done
  fi
  _aliases_why_deprecation "$alias_name"
  if [[ -z "$rows" && -z "$deprecation" ]]; then
    ui_warn "Alias" "not found: $alias_name"
    return 1
  fi
}

_aliases_stats() {
  local histfile="${HISTFILE:-$HOME/.zsh_history}" tmp_aliases
  if [[ ! -f "$histfile" ]]; then
    die "History file not found: $histfile"
  fi
  ui_header "Alias Usage (History)"
  ui_info "History file" "$histfile"
  echo ""
  tmp_aliases="$(umask 077 && mktemp)"
  # Self-clearing: left installed, the trap would fire again when
  # cmd_aliases returns, after tmp_aliases has gone out of scope.
  trap 'rm -f "$tmp_aliases"; trap - RETURN' RETURN
  emit_alias_manifest | awk -F'\t' '{print $1}' | sort -u >"$tmp_aliases"
  awk -v aliases_file="$tmp_aliases" '
      BEGIN {
        while ((getline < aliases_file) > 0) alias[$1]=1
      }
      {
        line=$0
        sub(/^:[[:space:]]*[0-9]+:[0-9]+;/, "", line) # zsh EXTENDED_HISTORY prefix
        split(line, parts, /[[:space:]]+/)
        cmd=parts[1]
        if (cmd in alias) count[cmd]++
      }
      END {
        for (k in count) printf "%7d  %s\n", count[k], k
      }
    ' "$histfile" | sort -nr | head -20
  rm -f "$tmp_aliases"
}

# Destination defaults to the checkout's docs/ but can be
# redirected with `--output PATH` (or `-` for stdout). The
# hardcoded path made this the one subcommand that could not be
# exercised without writing into the working tree:
# require_source_dir() resolves from the location of the lib that
# was sourced, so it always pointed at the real repo no matter
# how the sandbox redirected $HOME/.dotfiles.
_aliases_cheatsheet() {
  local src_dir out=""
  ui_header "Alias Cheatsheet"
  src_dir="$(require_source_dir)"
  while (($#)); do
    case "$1" in
      --output | -o)
        out="${2:-}"
        if [[ -z "$out" ]]; then
          die "Usage: dot aliases cheatsheet [--output PATH|-]"
          return 1 # die exits; this keeps the loop finite if it is stubbed
        fi
        shift 2
        ;;
      *)
        die "Unknown option for cheatsheet: $1"
        return 1
        ;;
    esac
  done
  out="${out:-$src_dir/docs/ALIASES_CHEATSHEET.md}"
  if [[ "$out" == "-" ]]; then
    bash "$src_dir/scripts/diagnostics/aliases-cheatsheet.sh"
  else
    mkdir -p "$(dirname "$out")"
    bash "$src_dir/scripts/diagnostics/aliases-cheatsheet.sh" >"$out"
    ui_ok "Generated" "$out"
  fi
}

# _aliases_tier <csv> <token> <label>: one enabled/disabled row.
_aliases_tier() {
  if alias_tier_enabled "$1" "$2"; then
    ui_ok "$3" "enabled"
  else
    ui_warn "$3" "disabled"
  fi
}

_aliases_tiers() {
  local profile ecosystems security_mode dangerous buckets eco
  profile="${DOTFILES_ALIAS_PROFILE:-standard}"
  ecosystems="${DOTFILES_ALIAS_ECOSYSTEMS:-all}"
  buckets="${DOTFILES_ALIAS_BUCKETS:-system,svn}"
  security_mode="${DOTFILES_SECURITY_MODE:-standard}"
  dangerous="${DOTFILES_ENABLE_DANGEROUS_ALIASES:-0}"

  ui_header "Alias Tiers"
  ui_info "Profile" "$profile"
  ui_info "Ecosystems" "$ecosystems"
  ui_info "Buckets" "$buckets"
  ui_info "Security Mode" "$security_mode"
  ui_info "Dangerous Aliases" "$dangerous"
  echo ""

  ui_header "Core (Always Loaded)"
  ui_ok "navigation" "cd, clear, default, diagnostics, ps"
  ui_ok "dev core" "git, editor, configuration, modern"
  ui_ok "cross-platform tooling" "docker, archives, disk-usage, rsync"
  echo ""

  ui_header "Ecosystems (Lazy)"
  for eco in python node rust network legacy; do
    _aliases_tier "$ecosystems" "$eco" "$eco"
  done
  _aliases_tier "$buckets" system "system bucket"
  _aliases_tier "$buckets" svn "svn bucket"
}

cmd_aliases() {
  local subcommand="${1:-list}"
  shift || true

  case "$subcommand" in
    list) _aliases_list ;;
    search) _aliases_search "$@" ;;
    why) _aliases_why "$@" ;;
    stats) _aliases_stats ;;
    cheatsheet) _aliases_cheatsheet "$@" ;;
    tiers) _aliases_tiers ;;
    *) die "Unknown aliases subcommand: $subcommand" ;;
  esac
}

cmd_alias_check() {
  ui_header "Alias Check"
  echo ""

  local alias_file="${HOME}/.config/shell/90-ux-aliases.sh"
  local zshrc_file="${HOME}/.config/zsh/.zshrc"
  local auto_ls_file="${HOME}/.config/shell/custom/auto_ls.zsh"
  local missing=0

  if [[ -f "$alias_file" ]]; then
    ui_ok "Aliases file" "$alias_file"
  else
    ui_err "Aliases file missing" "$alias_file"
    missing=1
  fi

  local required_aliases=(c q e l ll la lr lra lt lta h a d _ i)
  local a
  for a in "${required_aliases[@]}"; do
    if grep -Eq "^[[:space:]]*alias[[:space:]]+${a}=" "$alias_file" 2>/dev/null; then
      ui_ok "alias ${a}" "present"
    else
      ui_warn "alias ${a}" "missing"
      missing=1
    fi
  done

  if [[ -f "$auto_ls_file" ]]; then
    ui_ok "auto-ls hook" "$auto_ls_file"
  else
    ui_warn "auto-ls hook" "missing"
  fi

  if [[ -f "$zshrc_file" ]] && rg -q "auto_ls.zsh" "$zshrc_file"; then
    ui_ok "auto-ls sourced" "$zshrc_file"
  else
    ui_warn "auto-ls sourced" "not referenced in zshrc"
  fi

  echo ""
  if [[ "$missing" -eq 1 ]]; then
    ui_warn "Result" "Some aliases are missing; re-run 'chezmoi apply' and open a new shell."
    return 1
  fi
  ui_ok "Result" "All core aliases present"
}
