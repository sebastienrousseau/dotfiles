#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Sourced by dot_zshrc.tmpl / dot_bashrc; inherits set -euo pipefail from the caller.

# 10-secrets.sh: Optional secret bucket auto-loader
# Loads configured secret buckets into the current shell via
# `dot secrets load` (`dot env load` is the mise environment command).

if [[ "${DOTFILES_SECRETS_AUTO_LOAD:-0}" != "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

if ! command -v dot >/dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

# Walk the comma-separated bucket list with parameter expansion: no
# process substitution, no here-string, so nothing touches TMPDIR (zsh
# writes here-strings to a temp file) and it reads the same in bash and zsh.
_dot_secret_rest="${DOTFILES_SECRETS_BUCKET_NAMES:-},"
while [[ -n "$_dot_secret_rest" ]]; do
  _bucket="${_dot_secret_rest%%,*}"
  _dot_secret_rest="${_dot_secret_rest#*,}"
  [[ -n "$_bucket" ]] || continue
  _dot_secret_out="$(dot secrets load "$_bucket" 2>/dev/null || true)"
  case "$_dot_secret_out" in
    export\ * | typeset\ * | unset\ *)
      # `dot secrets load` only emits `export KEY=VALUE` lines: keys are
      # validated shell identifiers and values are printf %q-quoted.
      eval "$_dot_secret_out"
      ;;
    *)
      # Ignore empty or non-shell output
      ;;
  esac
done

unset _dot_secret_rest _dot_secret_out _bucket
