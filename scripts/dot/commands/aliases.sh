#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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

cmd_aliases() {
  local subcommand="${1:-list}"
  shift || true

  alias_tier_enabled() {
    local csv="${1:-all}"
    local token="${2:-}"
    if [[ "$csv" == "all" ]]; then
      return 0
    fi
    [[ ",${csv}," == *",${token},"* ]]
  }

  case "$subcommand" in
    list)
      ui_header "Aliases"
      echo ""
      printf "  %-18s %-42s %s\n" "Name" "Value" "Source"
      echo "  $(printf '%.18s' '------------------') $(printf '%.42s' '------------------------------------------') -------------------------"
      emit_alias_manifest | sort -t $'\t' -k1,1 | while IFS=$'\t' read -r name value file line; do
        printf "  %-18s %-42s %s:%s\n" "$name" "${value:0:42}" "${file##*/}" "$line"
      done
      ;;
    search)
      local query="${1:-}"
      if [[ -z "$query" ]]; then
        die "Usage: dot aliases search <term>"
      fi
      ui_header "Alias Search"
      ui_info "Query" "$query"
      echo ""
      local results
      results="$(emit_alias_manifest | rg -i "$query" || true)"
      if [[ -z "$results" ]]; then
        ui_warn "No matches" "$query"
        return 1
      fi
      printf "%s\n" "$results" | while IFS=$'\t' read -r name value file line; do
        printf "  %-18s %-42s %s:%s\n" "$name" "${value:0:42}" "$file" "$line"
      done
      ;;
    why)
      local alias_name="${1:-}"
      if [[ -z "$alias_name" ]]; then
        die "Usage: dot aliases why <alias>"
      fi
      ui_header "Alias Details"
      ui_info "Alias" "$alias_name"
      echo ""
      local rows
      rows="$(emit_alias_manifest | awk -F'\t' -v a="$alias_name" '$1==a')"
      local src_dir deprecations_file deprecation
      src_dir="$(require_source_dir)"
      deprecations_file="$src_dir/scripts/dot/data/alias-deprecations.tsv"
      if [[ -n "$rows" ]]; then
        printf "%s\n" "$rows" | while IFS=$'\t' read -r name value file line; do
          ui_ok "$name" "${value}"
          printf "    source: %s:%s\n" "$file" "$line"
        done
      fi
      if [[ -f "$deprecations_file" ]]; then
        deprecation="$(awk -F'\t' -v a="$alias_name" 'BEGIN{IGNORECASE=0} $1 !~ /^#/ && $1==a {print $0; exit}' "$deprecations_file")"
        if [[ -n "$deprecation" ]]; then
          local _a replacement remove_in note
          IFS=$'\t' read -r _a replacement remove_in note <<<"$deprecation"
          echo ""
          ui_warn "Deprecated" "yes"
          ui_info "Replacement" "$replacement"
          ui_info "Remove In" "$remove_in"
          ui_info "Note" "$note"
        fi
      fi
      if [[ -z "$rows" && -z "$deprecation" ]]; then
        ui_warn "Alias" "not found: $alias_name"
        return 1
      fi
      ;;
    stats)
      local histfile="${HISTFILE:-$HOME/.zsh_history}"
      if [[ ! -f "$histfile" ]]; then
        die "History file not found: $histfile"
      fi
      ui_header "Alias Usage (History)"
      ui_info "History file" "$histfile"
      echo ""
      local tmp_aliases
      tmp_aliases="$(umask 077 && mktemp)"
      trap 'rm -f "$tmp_aliases"' RETURN
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
      ;;
    cheatsheet)
      ui_header "Alias Cheatsheet"
      local src_dir out
      src_dir="$(require_source_dir)"
      out="$src_dir/docs/ALIASES_CHEATSHEET.md"
      bash "$src_dir/scripts/diagnostics/aliases-cheatsheet.sh" >"$out"
      ui_ok "Generated" "$out"
      ;;
    tiers)
      local profile ecosystems security_mode dangerous buckets
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
      if alias_tier_enabled "$ecosystems" "python"; then
        ui_ok "python" "enabled"
      else
        ui_warn "python" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "node"; then
        ui_ok "node" "enabled"
      else
        ui_warn "node" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "rust"; then
        ui_ok "rust" "enabled"
      else
        ui_warn "rust" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "network"; then
        ui_ok "network" "enabled"
      else
        ui_warn "network" "disabled"
      fi
      if alias_tier_enabled "$ecosystems" "legacy"; then
        ui_ok "legacy" "enabled"
      else
        ui_warn "legacy" "disabled"
      fi
      if alias_tier_enabled "$buckets" "system"; then
        ui_ok "system bucket" "enabled"
      else
        ui_warn "system bucket" "disabled"
      fi
      if alias_tier_enabled "$buckets" "svn"; then
        ui_ok "svn bucket" "enabled"
      else
        ui_warn "svn bucket" "disabled"
      fi
      ;;
    *)
      die "Unknown aliases subcommand: $subcommand"
      ;;
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
