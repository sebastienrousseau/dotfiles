#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
#
# scripts/dot/commands/init.sh
#
# `dot init <github-user>` — bootstrap a foreign dotfiles repo through
# this framework's harness. The §3 audit roadmap calls for an analogue
# to `chezmoi init <user>` that turns this tool from "one person's
# config" into a runtime for any dotfiles user.
#
# Behavior:
#   dot init alice                # clones github.com/alice/dotfiles via chezmoi,
#                                 # applies through the dot harness
#   dot init https://...          # explicit URL
#   dot init alice --dry-run      # preview without writing
#   dot init alice --no-apply     # clone only; don't run chezmoi apply
#
# Safety:
#   - Refuses to clobber an existing chezmoi source dir without --force.
#   - Disclaims that the target's scripts will run with the user's
#     privileges and prints the source URL for inspection.
#   - Verifies the source URL is HTTPS (no plain git://) so MITM is harder.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/ui.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/ui.sh"
# shellcheck source=../../../lib/dot/utils.sh disable=SC1091
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

_init_resolve_url() {
  local arg="$1"
  case "$arg" in
    http://*)
      printf "dot init: refusing plain HTTP (use HTTPS or git+ssh)\n" >&2
      return 2
      ;;
    https://* | git@*:*)
      # Trust full URLs as-is — these are the user's explicit intent.
      printf "%s\n" "$arg"
      ;;
    */*)
      # owner/repo shorthand: validate before constructing the URL so
      # a crafted argument can't smuggle shell metacharacters into
      # downstream tooling (chezmoi init, git clone).
      if [[ ! "$arg" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
        printf "dot init: invalid owner/repo (only [A-Za-z0-9._-]+/[A-Za-z0-9._-]+ allowed): %s\n" "$arg" >&2
        return 2
      fi
      printf "https://github.com/%s.git\n" "$arg"
      ;;
    *)
      # Bare user shorthand: same character whitelist as the path
      # segment of a GitHub URL.
      if [[ ! "$arg" =~ ^[A-Za-z0-9._-]+$ ]]; then
        printf "dot init: invalid user (only [A-Za-z0-9._-] allowed): %s\n" "$arg" >&2
        return 2
      fi
      printf "https://github.com/%s/dotfiles.git\n" "$arg"
      ;;
  esac
}

cmd_init() {
  local user_arg="" dry_run=0 apply=1 force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run | -n)
        dry_run=1
        shift
        ;;
      --no-apply)
        apply=0
        shift
        ;;
      --force | -f)
        force=1
        shift
        ;;
      --help | -h)
        cat <<EOF
Usage: dot init <github-user|owner/repo|url> [--dry-run] [--no-apply] [--force]

Bootstrap a foreign dotfiles repo through chezmoi + the dot harness.

Examples:
  dot init alice                # github.com/alice/dotfiles
  dot init alice/configs        # github.com/alice/configs
  dot init https://example.com/repo.git
  dot init alice --dry-run      # preview only
  dot init alice --no-apply     # clone but don't apply

Flags:
  --dry-run, -n   Show resolved URL + target dir without cloning.
  --no-apply      Clone the source but skip 'chezmoi apply'.
  --force,   -f   Overwrite an existing chezmoi source dir.
EOF
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        ui_err "Unknown flag" "$1"
        return 1
        ;;
      *)
        if [[ -n "$user_arg" ]]; then
          ui_err "Too many arguments" "$1"
          return 1
        fi
        user_arg="$1"
        shift
        ;;
    esac
  done

  [[ -n "$user_arg" ]] || {
    ui_err "init" "missing <user|repo|url>"
    return 1
  }

  local url
  url="$(_init_resolve_url "$user_arg")" || return $?

  if ! command -v chezmoi >/dev/null 2>&1; then
    ui_err "chezmoi" "not installed — run install.sh first"
    return 127
  fi

  local source_dir
  source_dir="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || echo "$HOME/.local/share/chezmoi")}"

  ui_header "Bootstrap dotfiles from $user_arg"
  ui_info "Source URL" "$url"
  ui_info "Target dir" "$source_dir"
  local _apply_label="no"
  [[ "$apply" -eq 1 ]] && _apply_label="yes"
  ui_info "Apply after?" "$_apply_label"

  if [[ "$dry_run" -eq 1 ]]; then
    ui_ok "Dry-run" "no changes made"
    return 0
  fi

  if [[ -e "$source_dir" ]] && [[ "$force" -ne 1 ]]; then
    ui_err "Refusing" "$source_dir already exists; pass --force to overwrite"
    return 1
  fi

  ui_warn "Trust" "The target repo's scripts will run with your user privileges."
  ui_warn "Trust" "Inspect $url before proceeding if you don't know the author."
  if [[ -t 0 ]] && [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    read -r -p "  Continue? [y/N] " resp
    case "$resp" in
      [yY] | [yY][eE][sS]) ;;
      *)
        ui_info "Init" "aborted by user"
        return 1
        ;;
    esac
  fi

  local chezmoi_args=(init --source "$source_dir")
  [[ "$apply" -eq 1 ]] && chezmoi_args+=(--apply)
  chezmoi_args+=("$url")

  ui_info "chezmoi" "${chezmoi_args[*]}"
  if chezmoi "${chezmoi_args[@]}"; then
    ui_ok "Init" "complete"
    if [[ "$apply" -eq 1 ]]; then
      ui_info "Hint" "run 'dot doctor' to validate the new environment"
    else
      ui_info "Hint" "run 'chezmoi diff' then 'chezmoi apply' when ready"
    fi
  else
    local rc=$?
    ui_err "Init" "chezmoi exited $rc"
    return "$rc"
  fi
}
